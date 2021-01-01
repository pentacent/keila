defmodule Keila.Auth.UserGroup do
  use Keila.Schema, prefix: "aug"

  schema "user_groups" do
    belongs_to(:user, Keila.Auth.User, type: Keila.Auth.User.Id)
    belongs_to(:group, Keila.Auth.Group, type: Keila.Auth.Group.Id)

    has_many(:user_group_roles, Keila.Auth.UserGroupRole)

    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:user_id, :group_id])
    |> unique_constraint([:user_id, :group_id])
  end

  @doc """
  Returns `Ecto.Query` for UserGroup for given `user_id` and `group_id`.

  Use with `Keila.Repo.one/1`
  """
  @spec find(integer(), integer()) :: Ecto.Query.t()
  def find(user_id, group_id) do
    from(ug in __MODULE__)
    |> where([ug], ug.user_id == ^user_id and ug.group_id == ^group_id)
  end
end
