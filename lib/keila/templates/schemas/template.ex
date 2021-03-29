defmodule Keila.Templates.Template do
  use Keila.Schema, prefix: "tpl"
  alias Keila.Projects.Project

  schema "templates" do
    field(:name, :string)
    field(:body, :string)
    field(:styles, :string)
    field(:assigns, :map)

    belongs_to(:project, Project, type: Project.Id)

    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :body, :styles, :assigns, :project_id])
    |> validate_required([:name, :project_id])
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :body, :styles, :assigns])
    |> validate_required([:name])
  end
end
