defmodule Keila.Contacts.Segment do
  use Keila.Schema, prefix: "sgm"

  schema "contacts_segments" do
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    field(:name, :string)

    field(:filter, :map)

    timestamps()
  end

  @spec creation_changeset(t(), Changeset.data()) :: Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :project_id, :filter])
  end

  @spec update_changeset(t(), Changeset.data()) :: Changeset.t(t())
  def update_changeset(struct, params) do
    struct
    |> cast(params, [:name, :filter])
  end
end
