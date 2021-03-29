defmodule Keila.Mailings.Campaign do
  use Keila.Schema, prefix: "mc"
  alias Keila.Mailings.Sender
  alias Keila.Projects.Project
  alias Keila.Templates.Template

  schema "mailings_campaigns" do
    field(:subject, :string)
    field(:text_body, :string)
    field(:html_body, :string)
    field(:sent_at, :utc_datetime)
    field(:scheduled_for, :utc_datetime)
    embeds_one(:settings, __MODULE__.Settings)
    belongs_to(:template, Template, type: Template.Id)
    belongs_to(:sender, Sender, type: Sender.Id)
    belongs_to(:project, Project, type: Project.Id)
    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:subject, :text_body, :html_body, :sender_id, :project_id, :template_id])
    |> cast_embed(:settings)
    |> validate_required([:subject, :project_id, :settings])
  end

  def update_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, [:subject, :text_body, :html_body, :sender_id, :template_id])
    |> cast_embed(:settings)
    |> validate_required([:subject])
  end

  def update_and_send_changeset(struct = %__MODULE__{}, params) do
    update_changeset(struct, params)
    |> validate_required([:sender_id])
  end

  @doc """
  This changeset can be used when generating a preview and no validation of
  required fields is desired.
  """
  def preview_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, [:subject, :text_body, :html_body, :sender_id, :template_id])
    |> cast_embed(:settings)
  end

  def schedule_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, [:scheduled_for])
    |> validate_scheduled_for()
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
      :gt -> [scheduled_for: "must be at least #{offset} seconds in the future"]
      _ -> []
    end
  end

  defp min_campaign_schedule_offset_and_threshold() do
    offset =
      Application.get_env(:keila, Keila.Mailings, [])
      |> Keyword.fetch!(:min_campaign_schedule_offset)

    threshold = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(offset, :second)

    {offset, threshold}
  end
end
