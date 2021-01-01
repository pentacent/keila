defmodule Keila.Auth.Token do
  use Keila.Schema, prefix: "at"
  alias Keila.Auth

  schema "tokens" do
    field(:key, :string, virtual: true)
    field(:stored_key, :string, source: :key)
    field(:scope, :string)
    field(:data, :map)
    belongs_to(:user, Auth.User, type: Auth.User.Id)
    field(:expires_at, :utc_datetime)

    timestamps(updated_at: false)
  end

  @doc """
  Changeset for inserting a new token with a random 32-bit key.

  If `:expires_at` is not set, a default expiry of one day is enforced.
  """
  @spec changeset(%{
          :user_id => integer(),
          :scope => String.t(),
          optional(:expires_at) => DateTime.t(),
          optional(:data) => map()
        }) :: Ecto.Changeset.t()
  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:user_id, :scope, :expires_at, :data])
    |> maybe_put_default_expires_at()
    |> put_random_key()
  end

  defp maybe_put_default_expires_at(changeset) do
    case get_change(changeset, :expires_at) do
      nil -> put_default_expires_at(changeset)
      _other -> changeset
    end
  end

  defp put_default_expires_at(changeset) do
    datetime =
      DateTime.utc_now() |> DateTime.add(1 * 24 * 60 * 60, :second) |> DateTime.truncate(:second)

    put_change(changeset, :expires_at, datetime)
  end

  defp put_random_key(changeset) do
    key = :crypto.strong_rand_bytes(32)
    base64_key = Base.url_encode64(key, padding: false)
    hashed_key = :crypto.hash(:sha256, key)

    changeset
    |> put_change(:stored_key, hashed_key)
    |> put_change(:key, base64_key)
  end

  @doc """
  Builds `Ecto.Query` to find specified token.
  """
  @spec find_token_query(String.t(), String.t()) :: Ecto.Query.t()
  def find_token_query(key, scope) do
    with {:ok, key} <- Base.url_decode64(key, padding: false) do
      hashed_key = :crypto.hash(:sha256, key)

      from(t in __MODULE__)
      |> where([t], t.scope == ^scope)
      |> where([t], t.expires_at >= fragment("NOW()"))
      |> where([t], t.stored_key == ^hashed_key)
    else
      _ -> from(t in __MODULE__, where: true == false)
    end
  end
end
