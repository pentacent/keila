defmodule Keila.Mailings.Campaign do
  use Keila.Schema, prefix: "mc"
  alias Keila.Contacts.Segment
  alias Keila.Mailings.Sender
  alias Keila.Projects.Project
  alias Keila.Templates.Template

  @update_fields [
    :subject,
    :text_body,
    :html_body,
    :json_body,
    :mjml_body,
    :preview_text,
    :sender_id,
    :template_id,
    :segment_id,
    :data
  ]
  @creation_fields [:project_id | @update_fields]

  schema "mailings_campaigns" do
    field :subject, :string
    field :text_body, :string
    field :html_body, :string
    field :json_body, :map
    field :mjml_body, :string
    field :preview_text, :string
    field :data, Keila.Repo.JsonField

    field :public_link_enabled, :boolean

    field :sent_at, :utc_datetime
    field :scheduled_for, :utc_datetime

    embeds_one :settings, __MODULE__.Settings
    belongs_to :template, Template, type: Template.Id
    belongs_to :sender, Sender, type: Sender.Id
    belongs_to :project, Project, type: Project.Id
    belongs_to :segment, Segment, type: Segment.Id

    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @creation_fields)
    |> cast_embed(:settings)
    |> validate_required([:subject, :project_id, :settings])
    |> validate_assocs_project()
    |> check_data_size_constraint()
  end

  def update_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, @update_fields)
    |> cast_embed(:settings)
    |> validate_required([:subject])
    |> validate_assocs_project()
    |> check_data_size_constraint()
  end

  def update_and_send_changeset(struct = %__MODULE__{}, params) do
    update_changeset(struct, params)
    |> validate_required([:sender_id])
  end

  @doc """
  This changeset can be used when generating a preview and no validation of
  required fields is desired.
  """
  def preview_changeset(struct_or_changeset, params) do
    struct_or_changeset
    |> cast(params, @update_fields)
    |> cast_embed(:settings)
  end

  def schedule_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, [:scheduled_for])
    |> validate_scheduled_for()
    |> validate_assocs_project()
  end

  defp validate_scheduled_for(changeset) do
    changeset
    |> maybe_validate_old_scheduled_for()
    |> validate_change(:scheduled_for, &maybe_validate_new_scheduled_for/2)
  end

  defp maybe_validate_old_scheduled_for(changeset = %{data: %__MODULE__{scheduled_for: nil}}),
    do: changeset

  defp maybe_validate_old_scheduled_for(changeset) do
    scheduled_for = changeset.data.scheduled_for
    {_offset, threshold} = min_campaign_schedule_offset_and_threshold()

    case DateTime.compare(threshold, scheduled_for) do
      :gt -> add_error(changeset, :scheduled_for, "is already about to be delivered")
      _ -> changeset
    end
  end

  defp maybe_validate_new_scheduled_for(:scheduled_for, nil), do: []

  defp maybe_validate_new_scheduled_for(:scheduled_for, scheduled_for) do
    {offset, threshold} = min_campaign_schedule_offset_and_threshold()

    case DateTime.compare(threshold, scheduled_for) do
      :gt ->
        [scheduled_for: {"must be at least %{offset} seconds in the future", [offset: offset]}]

      _ ->
        []
    end
  end

  defp min_campaign_schedule_offset_and_threshold() do
    offset =
      Application.get_env(:keila, Keila.Mailings, [])
      |> Keyword.fetch!(:min_campaign_schedule_offset)

    threshold = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(offset, :second)

    {offset, threshold}
  end

  defp validate_assocs_project(changeset) do
    changeset
    |> validate_assoc_project(:template, Template)
    |> validate_assoc_project(:sender, Sender)
    |> validate_assoc_project(:segment, Segment)
  end

  defp check_data_size_constraint(changeset) do
    changeset
    |> check_constraint(:data, name: :max_data_size, message: "max 32 KB data allowed")
  end
end
