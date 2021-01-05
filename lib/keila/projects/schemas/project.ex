defmodule Keila.Projects.Project do
  use Keila.Schema, prefix: "p"

  schema "projects" do
    field(:name, :string)
    belongs_to(:group, Keila.Auth.Group, type: Keila.Auth.Group.Id)
    timestamps()
  end

  @spec creation_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :group_id])
    |> validate_required([:name, :group_id])
  end

  @spec update_changeset(t() | Ecto.Changeset.data()) :: Ecto.Changeset.t(t)
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
