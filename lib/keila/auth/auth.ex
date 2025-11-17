defmodule Keila.Auth do
  @moduledoc """
  Functions for authentication and authorization.

  ## Authentication
  The `Auth` module includes functions to create, modify and
  authenticate users. Users may be referenced by their ID from other
  contexts to define ownership, membership, etc.

  ### User Registration/Sign-up Flow

  1. Create a `User` by specifying an email address and an optional
     password.
     Provide a callback function for  generating the verification link.
        {:ok, user} = Auth.create_user(%{email: "foo@example.com", password: "BatteryHorseStaple"}, url_fn: &url_fn/1)

  2. The User is sent an email notification with the activation link.
     Verify the User with the provided token:
        {:ok, user} = Auth.activate_user_from_token(token)

  3. The User has now been activated. You can now use other methods
     from this module.

  ### User Management

  #### Send password reset link
      :ok = Auth.send_password_reset_link(user_id, &url_fn/1)

  #### Send login link (for passwordless login)
      :ok = Auth.send_login_link(user_id, &url_fn/1)

  #### Change user email
  This uses a token to confirm the user’s new email address. The token
  is sent to the new email address. The address change is not applied
  until `update_user_email_from_token/1` is called.

      {:ok, _token} = Auth.update_user_email(user_id, %{"email" => "new@example.com"}, &url_fn/1)

      {:ok, updated_user} = Auth.update_user_email_from_token(token)


  ## Authorization
  The second part of this module allows you to implement granular role-based authorization in your application.
  Every `User` can be part of one or several `Group`s. In each `Group`, they may have one or several `Role`s which, in turn, have one or several `Permission`s attached:function()

  ### Example
      # Create users *Alice* and *Bob*
      {:ok, alice} = Auth.create_user(%{email: "alice@example.com"})
      {:ok, bob} = Auth.create_user(%{email: "alice@example.com"})

      # Create group *Employees*
      {:ok, employees_group} = Auth.create_group(%{name: employees})
  """
  require Logger
  require Ecto.Query
  import Ecto.Query

  use Keila.Repo

  alias Keila.Auth.{
    Emails,
    User,
    Group,
    Role,
    Permission,
    UserGroup,
    UserGroupRole,
    Token
  }

  @type token_url_fn :: (String.t() -> String.t())

  defp default_url_function(token) do
    Logger.debug("No URL function given")
    token
  end

  @doc """
  Returns root group.
  """
  @spec root_group() :: Group.t()
  def root_group() do
    Group.root_query()
    |> Repo.one!()
  end

  @spec create_group(Ecto.Changeset.data()) ::
          {:ok, Group.t()} | {:error, Ecto.Changeset.t(Group.t())}
  def create_group(params) do
    params
    |> Group.creation_changeset()
    |> Repo.insert()
  end

  @spec update_group(integer(), Ecto.Changeset.data()) ::
          {:ok, Group.t()} | {:error, Ecto.Changeset.t(Group.t())}
  def update_group(id, params) do
    Repo.get(Group, id)
    |> Group.update_changeset(params)
    |> Repo.update()
  end

  @spec create_role(Ecto.Changeset.data()) :: {:ok, Role.t()} | Ecto.Changeset.t(Role.t())
  def create_role(params) do
    params
    |> Role.changeset()
    |> Repo.insert()
  end

  @spec update_role(integer, Ecto.Changeset.data()) ::
          {:ok, Role.t()} | Ecto.Changeset.t(Role.t())
  def update_role(id, params) do
    Repo.get(Role, id)
    |> Role.changeset(params)
    |> Repo.update()
  end

  @spec create_permission(Ecto.Changeset.data()) ::
          {:ok, Role.t()} | Ecto.Changeset.t(Permission.t())
  def create_permission(params) do
    params
    |> Permission.changeset()
    |> Repo.insert()
  end

  @spec update_permission(integer(), Ecto.Changeset.data()) ::
          {:ok, Permission.t()} | Ecto.Changeset.t(Permission.t())
  def update_permission(id, params) do
    Repo.get(Permission, id)
    |> Permission.changeset(params)
    |> Repo.update()
  end

  @doc """
  Adds User with given `user_id` to Group specified with `group_id`.

  This function is idempotent.
  """
  @spec add_user_to_group(integer(), integer()) :: :ok | {:error, Changeset.t()}
  def add_user_to_group(user_id, group_id) do
    %{user_id: user_id, group_id: group_id}
    |> UserGroup.changeset()
    |> idempotent_insert()
  end

  @doc """
  Removes User with given `user_id` from Group specified with `group_id`.

  This function is idempotent.
  """
  @spec remove_user_from_group(integer(), integer()) :: :ok
  def remove_user_from_group(user_id, group_id) do
    from(ug in UserGroup)
    |> where([ug], ug.user_id == ^user_id and ug.group_id == ^group_id)
    |> idempotent_delete()
  end

  @doc """
  Grants User with given `user_id` Role specified with `role_id` in Group specified with `group_id`.

  If User is not yet a member of Group, User is added to Group.

  This function is idempotent.
  """
  @spec add_user_group_role(integer(), integer(), integer()) :: :ok
  def add_user_group_role(user_id, group_id, role_id) do
    :ok = add_user_to_group(user_id, group_id)
    user_group_id = UserGroup.find(user_id, group_id) |> select([ug], ug.id) |> Repo.one()

    %{user_group_id: user_group_id, role_id: role_id}
    |> UserGroupRole.changeset()
    |> idempotent_insert()
  end

  @doc """
  Removes from User with given `user_id` Role specified with `role_id` in Group specified with `group_id`.

  User is not removed as a member of Group.

  This function is idempotent.
  """
  @spec remove_user_group_role(integer(), integer(), integer()) :: :ok
  def remove_user_group_role(user_id, group_id, role_id) do
    UserGroupRole.find(user_id, group_id, role_id)
    |> idempotent_delete()
  end

  @doc """
  Returns a list with all `Groups` the User specified with `user_id`
  has a direct membership in.
  """
  @spec list_user_groups(User.id()) :: [Group.t()]
  def list_user_groups(user_id) do
    from(g in Group)
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> where([g, ug], ug.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns a list of all `User`s who have a direct membership in the `Group`
  specified by `group_id`.
  """
  @spec list_group_users(Group.id()) :: [User.t()]
  def list_group_users(group_id) do
    from(g in Group)
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> where([g, ug], ug.group_id == ^group_id)
    |> join(:inner, [g, ug], u in User, on: u.id == ug.user_id)
    |> select([g, ug, u], u)
    |> Repo.all()
  end

  @doc """
  Checks if User specified with `user_id` is a direct member of Group
  specified with `group_id`. Returns `true` or `false` accordingly.
  """
  @spec user_in_group?(User.id(), Group.id()) :: boolean()
  def user_in_group?(user_id, group_id) do
    from(g in Group)
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> where([g, ug], g.id == ^group_id and ug.user_id == ^user_id)
    |> Repo.exists?()
  end

  defp idempotent_insert(changeset) do
    changeset
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, %Changeset{errors: [{_, {_, [{:constraint, :unique}, _]}}]}} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp idempotent_delete(query) do
    query
    |> Repo.delete_all()
    |> case do
      {_, nil} -> :ok
    end
  end

  @doc """
  Returns `true` if `User` with `user_id` has `Permission` specified by `permission_name` in `Group` with `group_id`
  """
  @spec has_permission?(integer(), integer(), String.t(), Keyword.t()) :: boolean
  def has_permission?(user_id, group_id, permission_name, _opts \\ []) do
    groups_with_permission_query(user_id, permission_name)
    |> where([g], g.id == ^group_id)
    |> Repo.exists?()
  end

  @spec groups_with_permission(integer(), String.t(), Keyword.t()) :: [integer()]
  def groups_with_permission(user_id, permission_name, _opts \\ []) do
    groups_with_permission_query(user_id, permission_name)
    |> Repo.all()
  end

  defp groups_with_permission_query(user_id, permission_name) do
    groups_with_direct_permission =
      from(g in Group)
      |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
      |> where([g, ug], ug.user_id == ^user_id)
      |> join(:inner, [g, ug], ugr in assoc(ug, :user_group_roles))
      |> join(:inner, [g, ug, ugr], r in assoc(ugr, :role))
      |> join(:inner, [g, ug, ugr, r], p in assoc(r, :role_permissions))
      |> join(:inner, [g, ug, ugr, r, rp], p in assoc(rp, :permission))
      |> where([g, ug, ugr, r, rp, p], p.name == ^permission_name)

    groups_with_inherited_permission =
      groups_with_direct_permission
      |> where([g, ug, ugr, r, rp, p], rp.is_inherited == true)

    groups_without_inherited_permission =
      groups_with_direct_permission
      |> where([g, ug, ugr, r, rp, p], rp.is_inherited == false)

    recursion = join(Group, :inner, [g], gt in "with-inherited", on: g.parent_id == gt.id)

    cte = union_all(groups_with_inherited_permission, ^recursion)

    from({"with-inherited", Group})
    |> recursive_ctes(true)
    |> with_cte("with-inherited", as: ^cte)
    |> union(^groups_without_inherited_permission)
  end

  @doc """
  Retrieves user with given ID. If no such user exists, returns `nil`
  """
  @spec get_user(User.id()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Creates a new user and sends an verification email using `Tuser.Mailings`.
  Also creates a new Account and associates user with it.

  Specify the `url_fn` callback function to generate the verification token URL.

  ## Options
   - `:skip_activation_email` - Don’t send activation email if set to `true`


  ## Example

  params = %{email: "foo@bar.com"}
  url_fn = KeilaWeb.Router.Helpers.auth_activate_url/1
  """
  @spec create_user(map(), Keyword.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def create_user(params, opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, user} <- do_create_user(params),
           {:ok, account} <- Keila.Accounts.create_account(),
           :ok <- Keila.Accounts.set_user_account(user.id, account.id) do
        unless Keyword.get(opts, :skip_activation_email) do
          url_fn = Keyword.get(opts, :url_fn, &default_url_function/1)
          send_activation_link(user.id, url_fn)
        end

        user
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_create_user(params) do
    params
    |> User.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Returns a list of all users, sorted by creation date.

  ## Options
  - `:paginate` - `true` or Pagination options.

  If `:pagination` is not `true` or a list of options, a list of all results is returned.
  """
  @spec list_users() :: [User.t()] | Keila.Pagination.t(User.t())
  def list_users(opts \\ []) do
    query = from(u in User, order_by: u.inserted_at)

    case Keyword.get(opts, :paginate) do
      true -> Keila.Pagination.paginate(query)
      opts when is_list(opts) -> Keila.Pagination.paginate(query, opts)
      _ -> Repo.all(query)
    end
  end

  @doc """
  Deletes a user.
  This does not delete user project data.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_user(User.id()) :: :ok
  def delete_user(id) do
    from(u in User, where: u.id == ^id)
    |> idempotent_delete()
  end

  @doc """
  Activates user with given ID.

  Returns `{:ok, user} if successful; `:error` otherwise.
  """
  @spec activate_user(User.id()) :: {:ok, User.t()} | :error
  def activate_user(id) do
    case Repo.get(User, id) do
      user = %User{activated_at: nil} ->
        case User.activation_changeset(user) |> Repo.update() do
          {:ok, user} -> {:ok, user}
          _ -> :error
        end
    end
  end

  @doc """
  Looks up given `auth.activate` token and activates associated user.

  Returns `{:ok, user}` if successful; `:error` otherwise.
  """
  @spec activate_user_from_token(String.t()) :: {:ok, User.t()} | :error
  def activate_user_from_token(token) do
    case find_and_delete_token(token, "auth.activate") do
      token = %Token{} -> activate_user(token.user_id)
      _ -> :error
    end
  end

  @doc """
  Deactivates user with given ID by setting activated_at to nil.
  """
  @spec deactivate_user(User.id()) :: {:ok, User.t()} | :error
  def deactivate_user(id) do
    case Repo.get(User, id) do
      user = %User{} ->
        case user |> change(%{activated_at: nil}) |> Repo.update() do
          {:ok, user} -> {:ok, user}
          _ -> :error
        end
      _ -> :error
    end
  end

  @doc """
  Updates user profile and verification status for admin use.
  """
  @spec admin_update_user(User.id(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def admin_update_user(id, params) do
    case Repo.get(User, id) do
      user = %User{} ->
        user
        |> User.admin_update_changeset(params)
        |> Repo.update()
      _ -> {:error, %Ecto.Changeset{}}
    end
  end

  @doc """
  Updates user password from params.

  ## Example
      update_user_password(user_id, %{"password" => "NewSecurePassword"})
  """
  @spec update_user_password(User.id(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def update_user_password(id, params) do
    Repo.get(User, id)
    |> User.update_password_changeset(params)
    |> Repo.update()
  end

  @doc """
  Updates user email from params.

  The user email is not immediately updated. Instead, an `auth.udpate_email`
  token is generated and sent via email.

  Only once this token is confirmed via `update_user_email_from_token/1` is the
  new email address persisted.

  Returns `{:ok, user}` if new email is identical to current email;
  `{:ok, token}` if the token was created and sent out via email;
  `{:error, changeset}` if the change was invalid.

  ## Example
      update_user_password(user_id, %{"email" => "new@example.com"})
  """
  @spec update_user_email(User.id(), %{:email => String.t()}, token_url_fn) ::
          {:ok, Token.t()} | {:ok, User.t()} | {:error, Changeset.t(User.t())}
  def update_user_email(id, params, url_fn \\ &default_url_function/1) do
    user = Repo.get(User, id)
    changeset = User.update_email_changeset(user, params)

    if changeset.valid? do
      email = Changeset.get_change(changeset, :email)

      if not is_nil(email) do
        {:ok, token} =
          create_token(%{user_id: user.id, scope: "auth.update_email", data: %{email: email}})

        Emails.send!(:update_email, %{user: user, url: url_fn.(token.key)})
        {:ok, token}
      else
        {:ok, user}
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Looks up and deletes given `auth.update_email` token and updates associated
  user email address.

  Returns `{:ok, user}` if successful; `:error` otherwise.
  """
  @spec update_user_email_from_token(String.t()) ::
          {:ok, User.t()} | {:error, Changeset.t()} | :error
  def update_user_email_from_token(token) do
    case find_and_delete_token(token, "auth.update_email") do
      token = %Token{} ->
        user = Repo.get(User, token.user_id)
        params = %{email: token.data["email"]}
        Repo.update(User.update_email_changeset(user, params))

      _ ->
        :error
    end
  end

  @doc """
  Returns `User` with given `email` or `nil` if no such `User` exists.
  """
  @spec find_user_by_email(String.t()) :: User.t() | nil
  def find_user_by_email(email) when is_binary(email) do
    Repo.one(from(u in User, where: u.email == ^email))
  end

  def find_user_by_email(_), do: nil

  @doc """
  Returns `User` with given credentials or `nil` if no such `User` exists.

  ## Example

  find_user_by_credentials(%{"email" => "foo@bar.com", password: "BatteryHorseStaple"})
  # => %User{}
  """
  @spec find_user_by_credentials(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def find_user_by_credentials(params) do
    user = find_user_by_email(params["email"] || params[:email]) || %User{}

    case User.validate_password_changeset(user, params) do
      %{valid?: true} -> {:ok, user}
      changeset -> Changeset.apply_action(changeset, :update)
    end
  end

  @doc """
  Updates the `given_name` and `family_name` properites of a given `User`.
  """
  @spec update_user_name(User.id(), map()) :: {:ok, User.t()} | {:error, Changeset.t(User.t())}
  def update_user_name(id, params) do
    id
    |> get_user()
    |> User.update_name_changeset(params)
    |> Repo.update()
  end

  @spec set_user_locale(User.id(), String.t()) ::
          {:ok, User.t()} | {:error, Changeset.t(User.t())}
  def set_user_locale(id, locale) do
    id
    |> get_user()
    |> User.update_locale_changeset(%{locale: locale})
    |> Repo.update()
  end

  @doc """
  Creates a token for given `scope` and `user_id`.

  `:expires_at` may be specified to change the default expiration of one day.
  `:data` may be specified to store JSON data alongside the token.
  """
  @spec create_token(%{
          :scope => binary,
          :user_id => User.id(),
          optional(:data) => map(),
          optional(:expires_at) => DateTime.t()
        }) :: {:ok, Token.t()} | {:error, Ecto.Changeset.t(Token.t())}
  def create_token(params) do
    Token.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Finds and returns `Token` specified by `key` and `scope`. Returns `nil` if no such `Token` exists.
  """
  @spec find_token(String.t(), String.t()) :: Token.t() | nil
  def find_token(key, scope) do
    Token.find_token_query(key, scope)
    |> Repo.one()
  end

  @doc """
  Finds, deletes, and returns `Token` specified by `key` and `scope`. Returns `nil` if no such `Token` exists.

  Use this instead of `find_token/2` when you want to ensure a token can only be used once.
  """
  @spec find_and_delete_token(String.t(), String.t()) :: Token.t() | nil
  def find_and_delete_token(key, scope) do
    Token.find_token_query(key, scope)
    |> select([t], t)
    |> Repo.delete_all(returning: :all)
    |> case do
      {0, _} -> nil
      {1, [token]} -> token
    end
  end

  # TODO: The API Key functions should probably be extracted to a different module
  #       because they make assumptions about other domains and don't fit well
  #        within the Auth module
  @doc """
  Creates new API key for given User and Project.

  API Keys are Auth Tokens with the scope `"api"`.
  """
  @spec create_api_key(Keila.Auth.User.id(), Keila.Projects.Project.id(), Strimg.t()) ::
          {:ok, Token.t()}
  def create_api_key(user_id, project_id, name \\ nil) do
    create_token(%{
      scope: "api",
      user_id: user_id,
      data: %{"project_id" => project_id, "name" => name},
      expires_at: ~U[9999-12-31 23:59:00Z]
    })
  end

  @doc """
  Lists all API keys for given User and Project.
  """
  @spec get_user_project_api_keys(Keila.Auth.User.id(), Keila.Projects.Project.id()) :: [
          Token.t()
        ]
  def get_user_project_api_keys(user_id, project_id) do
    from(t in Token,
      where: t.user_id == ^user_id and fragment("?->>?", t.data, "project_id") == ^project_id,
      order_by: [desc: t.inserted_at]
    )
    |> Keila.Repo.all()
  end

  @doc """
  Finds and returns Token for given API key. Returns `nil` if Token doesn’t exist.
  """
  @spec find_api_key(String.t()) :: Token.t() | nil
  def find_api_key(key) do
    find_token(key, "api")
  end

  @doc """
  Deletes given API key.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_project_api_key(Keila.Projects.Project.id(), Token.id()) :: :ok
  def delete_project_api_key(project_id, token_id) do
    from(t in Token,
      where: t.id == ^token_id and fragment("?->>?", t.data, "project_id") == ^project_id
    )
    |> Keila.Repo.delete_all()

    :ok
  end

  @doc """
  Sends an email with the activation link to the given User.
  """
  @spec send_activation_link(User.id(), token_url_fn) :: :ok
  def send_activation_link(id, url_fn \\ &default_url_function/1) do
    user = Repo.get(User, id)

    if user.activated_at == nil do
      {:ok, token} = create_token(%{scope: "auth.activate", user_id: user.id})
      Emails.send!(:activate, %{user: user, url: url_fn.(token.key)})
    end

    :ok
  end

  @doc """
  Sends an email with a password reset token to given User.

  Verify the token with `find_and_delete_token("auth.reset", token_key)`
  """
  @spec send_password_reset_link(User.id(), token_url_fn) :: :ok
  def send_password_reset_link(id, url_fn \\ &default_url_function/1) do
    user = Repo.get(User, id)
    {:ok, token} = create_token(%{scope: "auth.reset", user_id: user.id})
    Emails.send!(:password_reset_link, %{user: user, url: url_fn.(token.key)})
    :ok
  end

  @doc """
  Sends an email with a login token to given User.

  This can be useful for implementing a "magic link" login.

  Verify the token with `find_and_delete_token("auth.login", token_key)`
  """
  @spec send_login_link(User.id(), token_url_fn) :: :ok
  def send_login_link(id, url_fn \\ &default_url_function/1) do
    user = Repo.get(User, id)
    {:ok, token} = create_token(%{scope: "auth.login", user_id: user.id})
    Emails.send!(:login_link, %{user: user, url: url_fn.(token.key)})
    :ok
  end

  @doc """
  Enables two-factor authentication for a user.
  """
  @spec enable_two_factor_auth(User.id()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def enable_two_factor_auth(user_id) do
    user = Repo.get(User, user_id)
    
    # Generate backup codes
    backup_codes = for _ <- 1..10, do: generate_backup_code()
    
    user
    |> User.update_two_factor_changeset(%{two_factor_enabled: true, two_factor_backup_codes: backup_codes})
    |> Repo.update()
  end

  @doc """
  Disables two-factor authentication for a user.
  """
  @spec disable_two_factor_auth(User.id()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def disable_two_factor_auth(user_id) do
    user = Repo.get(User, user_id)
    
    user
    |> User.update_two_factor_changeset(%{two_factor_enabled: false, two_factor_backup_codes: []})
    |> Repo.update()
  end

  @doc """
  Generates and sends a two-factor authentication code to the user's email.
  Returns the generated code for verification.
  """
  @spec send_two_factor_code(User.id()) :: {:ok, String.t()} | :error
  def send_two_factor_code(user_id) do
    user = Repo.get(User, user_id)
    
    if user && user.two_factor_enabled do
      code = generate_two_factor_code()
      expires_at = DateTime.utc_now() |> DateTime.add(10, :minute) |> DateTime.truncate(:second)
      
      {:ok, _token} = create_token(%{
        scope: "auth.two_factor",
        user_id: user.id,
        data: %{code: code},
        expires_at: expires_at
      })
      
      Emails.send!(:two_factor_code, %{user: user, code: code})
      {:ok, code}
    else
      :error
    end
  end

  @doc """
  Verifies a two-factor authentication code.
  """
  @spec verify_two_factor_code(User.id(), String.t()) :: {:ok, User.t()} | :error
  def verify_two_factor_code(user_id, code) do
    user = Repo.get(User, user_id)
    
    if user && user.two_factor_enabled do
      # Check if it's a backup code
      if code in user.two_factor_backup_codes do
        # Remove used backup code
        remaining_codes = List.delete(user.two_factor_backup_codes, code)
        case user
        |> User.update_two_factor_changeset(%{two_factor_backup_codes: remaining_codes})
        |> Repo.update() do
          {:ok, updated_user} -> {:ok, updated_user}
          {:error, _changeset} -> :error
        end
      else
        # Check if it's a valid 2FA code
        case find_and_delete_token_by_user_and_data(user_id, "auth.two_factor", %{code: code}) do
          %Token{} -> {:ok, user}
          _ -> :error
        end
      end
    else
      :error
    end
  end

  defp generate_two_factor_code do
    :rand.uniform(999999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp generate_backup_code do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
  end

  defp find_and_delete_token_by_user_and_data(user_id, scope, data) do
    from(t in Token,
      where: t.user_id == ^user_id and t.scope == ^scope and t.data == ^data and t.expires_at > ^DateTime.utc_now()
    )
    |> Repo.one()
    |> case do
      nil -> nil
      token ->
        Repo.delete(token)
        token
    end
  end

  @doc """
  Starts WebAuthn registration process for a user.
  Returns challenge and user information needed for the client.
  """
  @spec start_webauthn_registration(User.id()) :: {:ok, map()} | {:error, String.t()}
  def start_webauthn_registration(user_id) do
    user = Repo.get(User, user_id)
    
    if user do
      # Clean up any existing registration tokens for this user
      from(t in Token,
        where: t.user_id == ^user.id and t.scope == "auth.webauthn_registration"
      )
      |> Repo.delete_all()
      
      challenge = Wax.new_registration_challenge(
        origin: get_origin(),
        rp_id: get_rp_id()
      )
      
      expires_at = DateTime.utc_now() |> DateTime.add(5, :minute) |> DateTime.truncate(:second)
      
      # Store only serializable challenge data in token for verification
      {:ok, _token} = create_token(%{
        scope: "auth.webauthn_registration",
        user_id: user.id,
        data: %{
          challenge_bytes: Base.encode64(challenge.bytes),
          origin: challenge.origin,
          rp_id: challenge.rp_id
        },
        expires_at: expires_at
      })
      
      rp = %{
        id: get_rp_id(),
        name: "Keila"
      }
      
      user_info = %{
        id: user.id,
        name: user.email,
        displayName: "#{user.given_name} #{user.family_name}" |> String.trim()
      }
      
      {:ok, %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        rp: rp,
        user: user_info,
        pubKeyCredParams: [%{type: "public-key", alg: -7}], # ES256
        authenticatorSelection: %{
          authenticatorAttachment: "platform",
          userVerification: "preferred"
        }
      }}
    else
      {:error, "User not found"}
    end
  end

  @doc """
  Completes WebAuthn registration process.
  """
  @spec complete_webauthn_registration(User.id(), map()) :: {:ok, User.t()} | {:error, String.t()}
  def complete_webauthn_registration(user_id, attestation_response) do
    user = Repo.get(User, user_id)
    
    # Find the most recent challenge token
    challenge_token = from(t in Token,
      where: t.user_id == ^user_id and t.scope == "auth.webauthn_registration" and t.expires_at > ^DateTime.utc_now(),
      order_by: [desc: t.inserted_at],
      limit: 1
    )
    |> Repo.one()
    
    if user && challenge_token do
      # Reconstruct the challenge from stored data
      challenge_data = challenge_token.data
      challenge = %Wax.Challenge{
        type: :attestation,
        bytes: Base.decode64!(challenge_data["challenge_bytes"]),
        origin: challenge_data["origin"],
        rp_id: challenge_data["rp_id"],
        token_binding_status: nil,
        issued_at: System.system_time(:second),
        origin_verify_fun: {Wax, :origins_match?, []},
        acceptable_authenticator_statuses: ["FIDO_CERTIFIED", "FIDO_CERTIFIED_L1", "FIDO_CERTIFIED_L1plus", "FIDO_CERTIFIED_L2", "FIDO_CERTIFIED_L2plus", "FIDO_CERTIFIED_L3", "FIDO_CERTIFIED_L3plus"],
        android_key_allow_software_enforcement: false,
        allow_credentials: [],
        attestation: "none",
        silent_authentication_enabled: false,
        timeout: 1200,
        trusted_attestation_types: [:none, :self, :basic, :uncertain, :attca, :anonca],
        user_verification: "preferred",
        verify_trust_root: true
      }
      
      # Convert the attestation response from arrays back to binaries
      attestation_object = attestation_response["response"]["attestationObject"] |> Enum.into(<<>>, &<<&1>>)
      client_data_json = attestation_response["response"]["clientDataJSON"] |> Enum.into(<<>>, &<<&1>>)
      
      # Verify the attestation using Wax
      case Wax.register(attestation_object, client_data_json, challenge) do
        {:ok, {authenticator_data, _attestation_result}} ->
          # Extract credential info
          credential_id = attestation_response["id"]
          credential_public_key = authenticator_data.attested_credential_data.credential_public_key
          
          # Create credential record
          credential = %{
            id: credential_id,
            public_key: Base.encode64(:erlang.term_to_binary(credential_public_key)),
            created_at: DateTime.utc_now(),
            last_used_at: nil,
            name: "Security Key"
          }
          
          # Add credential to user
          updated_credentials = [credential | user.webauthn_credentials]
          
          changeset = user
          |> User.update_webauthn_changeset(%{webauthn_credentials: updated_credentials})
          
          case Repo.update(changeset) do
            {:ok, updated_user} ->
              # Delete all registration tokens for this user
              from(t in Token,
                where: t.user_id == ^user.id and t.scope == "auth.webauthn_registration"
              )
              |> Repo.delete_all()
              {:ok, updated_user}
            {:error, _changeset} ->
              {:error, "Failed to save credential"}
          end
          
        {:error, reason} ->
          {:error, "WebAuthn verification failed: #{inspect(reason)}"}
      end
    else
      {:error, "Invalid registration session"}
    end
  end

  @doc """
  Starts WebAuthn authentication process.
  Returns challenge and allowed credentials.
  """
  @spec start_webauthn_authentication(User.id()) :: {:ok, map()} | {:error, String.t()}
  def start_webauthn_authentication(user_id) do
    user = Repo.get(User, user_id)
    
    if user && length(user.webauthn_credentials) > 0 do
      # Clean up any existing authentication tokens for this user
      from(t in Token,
        where: t.user_id == ^user.id and t.scope == "auth.webauthn_authentication"
      )
      |> Repo.delete_all()
      
      # Prepare credentials for Wax
      cred_ids_and_keys = Enum.map(user.webauthn_credentials, fn cred ->
        {cred["id"], :erlang.binary_to_term(Base.decode64!(cred["public_key"]))}
      end)
      
      challenge = Wax.new_authentication_challenge(
        allow_credentials: cred_ids_and_keys,
        origin: get_origin(),
        rp_id: get_rp_id()
      )
      
      expires_at = DateTime.utc_now() |> DateTime.add(5, :minute) |> DateTime.truncate(:second)
      
      # Store only serializable challenge data in token for verification
      {:ok, _token} = create_token(%{
        scope: "auth.webauthn_authentication",
        user_id: user.id,
        data: %{
          challenge_bytes: Base.encode64(challenge.bytes),
          origin: challenge.origin,
          rp_id: challenge.rp_id
        },
        expires_at: expires_at
      })
      
      allowed_credentials = Enum.map(user.webauthn_credentials, fn cred ->
        %{
          type: "public-key",
          id: cred["id"]
        }
      end)
      
      {:ok, %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        allowCredentials: allowed_credentials,
        userVerification: "preferred"
      }}
    else
      {:error, "No WebAuthn credentials found"}
    end
  end

  @doc """
  Completes WebAuthn authentication process.
  """
  @spec complete_webauthn_authentication(User.id(), map()) :: {:ok, User.t()} | {:error, String.t()}
  def complete_webauthn_authentication(user_id, assertion_response) do
    user = Repo.get(User, user_id)
    
    # Find the most recent challenge token
    challenge_token = from(t in Token,
      where: t.user_id == ^user_id and t.scope == "auth.webauthn_authentication" and t.expires_at > ^DateTime.utc_now(),
      order_by: [desc: t.inserted_at],
      limit: 1
    )
    |> Repo.one()
    
    if user && challenge_token do
      # Rebuild credentials from user record
      # Note: credential IDs are stored as base64url strings but Wax expects binary
      cred_ids_and_keys = Enum.map(user.webauthn_credentials, fn cred ->
        {Base.url_decode64!(cred["id"], padding: false), :erlang.binary_to_term(Base.decode64!(cred["public_key"]))}
      end)
      
      # Reconstruct the challenge from stored data
      challenge_data = challenge_token.data
      challenge = %Wax.Challenge{
        type: :assertion,
        bytes: Base.decode64!(challenge_data["challenge_bytes"]),
        origin: challenge_data["origin"],
        rp_id: challenge_data["rp_id"],
        token_binding_status: nil,
        issued_at: System.system_time(:second),
        origin_verify_fun: {Wax, :origins_match?, []},
        acceptable_authenticator_statuses: ["FIDO_CERTIFIED", "FIDO_CERTIFIED_L1", "FIDO_CERTIFIED_L1plus", "FIDO_CERTIFIED_L2", "FIDO_CERTIFIED_L2plus", "FIDO_CERTIFIED_L3", "FIDO_CERTIFIED_L3plus"],
        android_key_allow_software_enforcement: false,
        allow_credentials: cred_ids_and_keys,
        attestation: "none",
        silent_authentication_enabled: false,
        timeout: 1200,
        trusted_attestation_types: [:none, :self, :basic, :uncertain, :attca, :anonca],
        user_verification: "preferred",
        verify_trust_root: true
      }
      
      credential_id = assertion_response["id"]
      
      # Debug logging for credential lookup
      require Logger
      Logger.info("Frontend credential_id: #{inspect(credential_id)}")
      Logger.info("Frontend credential_id type: #{credential_id |> to_string() |> String.length()}")
      Logger.info("Available credentials:")
      Enum.each(user.webauthn_credentials, fn cred ->
        stored_id = cred["id"]
        Logger.info("  - Stored: #{inspect(stored_id)} (type: #{stored_id |> to_string() |> String.length()})")
        Logger.info("  - Match: #{stored_id == credential_id}")
      end)
      
      # Find the credential
      credential = Enum.find(user.webauthn_credentials, fn cred ->
        cred["id"] == credential_id
      end)
      
      if credential do
        # Convert assertion response from arrays back to binaries  
        raw_id = Base.url_decode64!(credential_id, padding: false)
        authenticator_data = assertion_response["response"]["authenticatorData"] |> Enum.into(<<>>, &<<&1>>)
        signature = assertion_response["response"]["signature"] |> Enum.into(<<>>, &<<&1>>)
        client_data_json = assertion_response["response"]["clientDataJSON"] |> Enum.into(<<>>, &<<&1>>)
        
        # Debug logging
        require Logger
        Logger.info("WebAuthn authentication attempt for credential_id: #{credential_id}")
        
        # Verify the assertion using Wax
        case Wax.authenticate(raw_id, authenticator_data, signature, client_data_json, challenge) do
          {:ok, _authenticator_data} ->
            # Update last used timestamp
            updated_credential = Map.put(credential, "last_used_at", DateTime.utc_now())
            updated_credentials = Enum.map(user.webauthn_credentials, fn cred ->
              if cred["id"] == credential_id, do: updated_credential, else: cred
            end)
            
            changeset = user
            |> User.update_webauthn_changeset(%{webauthn_credentials: updated_credentials})
            
            case Repo.update(changeset) do
              {:ok, updated_user} ->
                # Delete all authentication tokens for this user
                from(t in Token,
                  where: t.user_id == ^user.id and t.scope == "auth.webauthn_authentication"
                )
                |> Repo.delete_all()
                {:ok, updated_user}
              {:error, _changeset} ->
                {:ok, user} # Still allow authentication even if timestamp update fails
            end
            
          {:error, reason} ->
            {:error, "WebAuthn authentication failed: #{inspect(reason)}"}
        end
      else
        {:error, "Credential not found"}
      end
    else
      {:error, "Invalid authentication session"}
    end
  end

  @doc """
  Removes a WebAuthn credential from a user.
  """
  @spec remove_webauthn_credential(User.id(), String.t()) :: {:ok, User.t()} | {:error, String.t()}
  def remove_webauthn_credential(user_id, credential_id) do
    user = Repo.get(User, user_id)
    
    if user do
      updated_credentials = Enum.reject(user.webauthn_credentials, fn cred ->
        cred["id"] == credential_id
      end)
      
      changeset = user
      |> User.update_webauthn_changeset(%{webauthn_credentials: updated_credentials})
      
      case Repo.update(changeset) do
        {:ok, updated_user} ->
          {:ok, updated_user}
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, "User not found"}
    end
  end

  @spec remove_all_webauthn_credentials(user_id :: String.t()) :: 
    {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def remove_all_webauthn_credentials(user_id) do
    user = Repo.get(User, user_id)
    
    if user do
      user
      |> User.update_webauthn_changeset(%{webauthn_credentials: []})
      |> Repo.update()
    else
      {:error, "User not found"}
    end
  end

  # Private helper functions for WebAuthn
  
  defp get_origin do
    endpoint_config = Application.get_env(:keila, KeilaWeb.Endpoint, [])
    url_config = Keyword.get(endpoint_config, :url, [])
    scheme = if Keyword.get(url_config, :scheme) == "https", do: "https", else: "http"
    host = Keyword.get(url_config, :host, "localhost")
    port = Keyword.get(url_config, :port, 4000)
    
    if (scheme == "https" && port == 443) || (scheme == "http" && port == 80) do
      "#{scheme}://#{host}"
    else
      "#{scheme}://#{host}:#{port}"
    end
  end
  
  defp get_rp_id do
    endpoint_config = Application.get_env(:keila, KeilaWeb.Endpoint, [])
    url_config = Keyword.get(endpoint_config, :url, [])
    Keyword.get(url_config, :host, "localhost")
  end
end
