defmodule Keila.Auth.User do
  use Keila.Schema, prefix: "u"

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    field(:locale, :string)

    field(:activated_at, :utc_datetime)

    has_many(:user_groups, Keila.Auth.UserGroup)
    has_many(:group_roles, through: [:user_groups, :user_group_roles])
    timestamps()
  end

  @doc """
  Changeset for User creation.
  """
  @spec creation_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :password, :locale])
    |> validate_email()
    |> validate_password()
  end

  @doc """
  Changeset for User updates
  """
  @spec update_email_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def update_email_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email])
    |> validate_email()
  end

  @spec update_locale_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def update_locale_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:locale])
  end

  @spec update_password_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def update_password_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:password])
    |> validate_email()
    |> validate_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 255)
    |> unique_constraint(:email)
  end
  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 10)
    |> prepare_changes(&put_password_hash/1)
  end

  defp put_password_hash(changeset) do
    password = get_change(changeset, :password)

    changeset
    |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  @doc """
  Changeset that validates password in `params` against hashed password in `struct`.
  """
  @spec validate_password_changeset(nil | t() | Ecto.Changeset.data()) :: Ecto.Changeset.t()
  def validate_password_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:password])
    |> validate_current_password()
  end

  defp validate_current_password(%{data: %{password_hash: hash}} = changeset)
       when hash not in ["", nil] do
    password = get_change(changeset, :password) || ""

    if Argon2.verify_pass(password, hash) do
      changeset
    else
      put_invalid_password_error(changeset)
    end
  end

  defp validate_current_password(changeset) do
    put_invalid_password_error(changeset, true)
  end

  defp put_invalid_password_error(changeset, no_user_verify? \\ false) do
    if no_user_verify?, do: Argon2.no_user_verify()
    add_error(changeset, :password, "is incorrect")
  end

  def activation_changeset(struct \\ %__MODULE__{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    struct
    |> change(%{activated_at: now})
  end
end
