defmodule Keila.Auth.Role do
  use Keila.Schema, prefix: "ar"

  schema "roles" do
    field(:name, :string)
    has_many(:role_permissions, Keila.Auth.RolePermission)

    belongs_to(:parent, __MODULE__,
      foreign_key: :parent_id,
      references: :id,
      type: Keila.Auth.Role.Id
    )

    timestamps()
  end

  @spec changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :parent_id])
    |> foreign_key_constraint(:parent_id)
  end
end
