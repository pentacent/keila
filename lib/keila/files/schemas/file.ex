defmodule Keila.Files.File do
  use Keila.Schema, uuid: true
  alias Keila.Projects.Project

  schema "files" do
    field(:filename, :string)
    field(:type, :string)
    field(:size, :integer)
    field(:sha256, :binary)

    field(:adapter, :string)
    field(:adapter_data, :map)

    belongs_to(:project, Project, type: Project.Id)

    timestamps()
  end

  @spec creation_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:uuid, :filename, :type, :size, :sha256, :adapter, :adapter_data, :project_id])
    |> validate_required([:uuid, :project_id, :size, :adapter, :adapter_data])
  end
end
