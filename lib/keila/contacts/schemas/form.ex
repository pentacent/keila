defmodule Keila.Contacts.Form do
  use Keila.Schema, prefix: "frm"
  alias Keila.Templates.Template
  alias Keila.Mailings.Sender
  alias Keila.Mailings.Email

  schema "contacts_forms" do
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    field(:name, :string)

    embeds_one(:settings, Keila.Contacts.Form.Settings)
    embeds_many(:field_settings, Keila.Contacts.Form.FieldSettings, on_replace: :delete)

    belongs_to(:sender, Sender, type: Sender.Id)

    embeds_one(:welcome_email, Email, on_replace: :update)
    embeds_one(:double_opt_in_email, Email, on_replace: :update)

    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :project_id, :sender_id])
    |> cast_embeds()
    |> validate_assoc_projects()
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :sender_id])
    |> cast_embeds()
    |> validate_assoc_projects()
  end

  defp cast_embeds(changeset) do
    changeset
    |> cast_embed(:settings)
    |> cast_embed(:field_settings)
    |> cast_embed(:welcome_email, with: &Email.changeset(&1, &2, require_content: false))
    |> cast_embed(:double_opt_in_email, with: &Email.changeset(&1, &2, require_content: false))
    |> maybe_ensure_email_embed_exists(:welcome_email, :welcome_enabled)
    |> maybe_ensure_email_embed_exists(:double_opt_in_email, :double_opt_in_required)
  end

  defp validate_assoc_projects(changeset) do
    changeset
    |> validate_assoc_project(:sender, Sender)
    |> validate_embed_assoc_project(:welcome_email, :template, Template)
    |> validate_embed_assoc_project(:double_opt_in_email, :template, Template)
  end

  defp maybe_ensure_email_embed_exists(changeset, field, enabled_key) do
    enabled? = match?(%{^enabled_key => true}, get_field(changeset, :settings))

    if enabled? and is_nil(get_field(changeset, field)) do
      put_embed(changeset, field, %Email{type: :markdown})
    else
      changeset
    end
  end
end
