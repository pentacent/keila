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
        {:ok, user} = Auth.create_user(%{email: "foo@example.com", password: "BatteryHorseStaple"}, &url_fn/1)

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
  Creates a new user and sends an verification email using `Tuser.Mailings`.

  Specify the `url_fn` callback function to generate the verification token URL.

  ## Example

  params = %{email: "foo@bar.com"}
  url_fn = MyAppWeb.Router.Helpers.auth_activate_url/1
  """
  @spec create_user(map(), token_url_fn) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def create_user(params, url_fn \\ &default_url_function/1) do
    with {:ok, user} <- do_create_user(params) do
      send_activation_link(user.id, url_fn)
      {:ok, user}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
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
  Looks up given `auth.activate` token and activates assocaited user.

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
    changeset = User.update_changeset(user, params)

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
        Repo.update(User.update_changeset(user, params))

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
end
