defmodule Keila.Contacts.Form do
  use Keila.Schema, prefix: "frm"

  schema "contacts_forms" do
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    field(:name, :string)

    embeds_one(:settings, Keila.Contacts.Form.Settings)
    embeds_many(:field_settings, Keila.Contacts.Form.FieldSettings)
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :project_id])
    |> cast_embed(:settings)
    |> cast_embed(:field_settings)
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
    |> cast_embed(:settings)
    |> cast_embed(:field_settings)
  end
end
