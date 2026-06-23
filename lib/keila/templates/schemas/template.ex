defmodule Keila.Templates.Template do
  use Keila.Schema, prefix: "tpl"
  alias Keila.Projects.Project

  schema "templates" do
    field(:name, :string)
    field(:styles, :string)
    field(:assigns, :map)

    field(:type, Ecto.Enum, values: [text: 0, html: 1, mjml: 10, hybrid: 20])
    field(:mjml_body, :string)
    field(:html_body, :string)
    field(:text_body, :string)

    belongs_to(:project, Project, type: Project.Id)

    timestamps()
  end

  @update_fields [
    :name,
    :styles,
    :assigns,
    :mjml_body,
    :html_body,
    :text_body
  ]
  @creation_fields [:project_id, :type | @update_fields]

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @creation_fields)
    |> validate_required([:name, :project_id, :type])
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @update_fields)
    |> validate_required([:name])
  end
end
