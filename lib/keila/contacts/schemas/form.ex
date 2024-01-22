defmodule Keila.Contacts.Form do
  use Keila.Schema, prefix: "frm"
  alias Keila.Templates.Template
  alias Keila.Mailings.Sender

  schema "contacts_forms" do
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    field(:name, :string)

    embeds_one(:settings, Keila.Contacts.Form.Settings)
    embeds_many(:field_settings, Keila.Contacts.Form.FieldSettings, on_replace: :delete)

    # Double opt-in properties
    belongs_to(:sender, Sender, type: Sender.Id)
    belongs_to(:template, Template, type: Template.Id)

    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :project_id, :sender_id, :template_id])
    |> cast_embed(:settings)
    |> cast_embed(:field_settings)
    |> validate_assoc_project(:sender, Sender)
    |> validate_assoc_project(:template, Template)
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :sender_id, :template_id])
    |> cast_embed(:settings)
    |> cast_embed(:field_settings)
    |> validate_assoc_project(:sender, Sender)
    |> validate_assoc_project(:template, Template)
  end
end
