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
    |> cast_embed(:field_settings,
      sort_param: :field_settings_sort,
      drop_param: :field_settings_drop
    )
    |> validate_email_field_settings()
    |> validate_unique_data_keys()
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
      put_embed(changeset, field, new_email())
    else
      changeset
    end
  end

  @doc """
  Returns a new, empty form email for inserting when enabling form emails.
  """
  @spec new_email() :: Email.t()
  def new_email() do
    %Email{type: :markdown, editor_config: %Email.EditorConfig{enable_wysiwyg: false}}
  end

  # The email field is mandatory for every Contact, so it must always be cast and required.
  defp validate_email_field_settings(changeset) do
    field_settings = get_field(changeset, :field_settings)

    case Enum.find(field_settings, &(&1.field == :email)) do
      nil -> add_error(changeset, :field_settings, "must include an email field")
      %{cast: true, required: true} -> changeset
      _other -> add_error(changeset, :field_settings, "email field must be cast and required")
    end
  end

  defp validate_unique_data_keys(changeset) do
    case get_change(changeset, :field_settings) do
      nil ->
        changeset

      field_changesets ->
        key_counts = field_changesets |> Enum.map(&data_key/1) |> Enum.frequencies()

        field_changesets =
          Enum.map(field_changesets, &maybe_add_duplicate_key_error(&1, key_counts))

        %{
          changeset
          | changes: %{changeset.changes | field_settings: field_changesets},
            valid?: changeset.valid? and Enum.all?(field_changesets, & &1.valid?)
        }
    end
  end

  # Returns the key of a data field, or nil for removed (replaced) data fields and other fields.
  defp data_key(%{action: :replace}), do: nil

  defp data_key(field_changeset) do
    if get_field(field_changeset, :field) == :data, do: get_field(field_changeset, :key)
  end

  defp maybe_add_duplicate_key_error(field_changeset, key_counts) do
    key = data_key(field_changeset)

    if key && key_counts[key] > 1,
      do: add_error(field_changeset, :key, "has already been taken"),
      else: field_changeset
  end
end
