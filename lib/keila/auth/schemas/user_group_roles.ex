defmodule Keila.Auth.UserGroupRole do
  use Keila.Schema, prefix: "aur"

  schema "user_group_roles" do
    belongs_to(:user_group, Keila.Auth.UserGroup, type: Keila.Auth.UserGroup.Id)
    belongs_to(:role, Keila.Auth.Role, type: Keila.Auth.Role.Id)

    has_many(:role_permissions, Keila.Auth.RolePermission,
      references: :role_id,
      foreign_key: :role_id
    )

    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:user_group_id, :role_id])
    |> unique_constraint([:user_group_id, :role_id])
  end

  @doc """
  Returns `Ecto.Query` for UserGroupRole for given `user_id`, `group_id`, `role_id`.

  Use with `Keila.Repo.one/1`
  """
  @spec find(integer(), integer(), integer()) :: Ecto.Query.t()
  def find(user_id, group_id, role_id) do
    from(ug in __MODULE__)
    |> where([ugr], ugr.role_id == ^role_id)
    |> join(:inner, [ugr], ug in assoc(ugr, :user_group))
    |> where([ugr, ug], ug.user_id == ^user_id and ug.group_id == ^group_id)
  end
end
