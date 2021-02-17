defmodule Keila.Mailings.Campaign do
  use Keila.Schema, prefix: "mc"
  alias Keila.Mailings.Sender
  alias Keila.Projects.Project

  schema "mailings_campaigns" do
    field(:subject, :string)
    field(:text_body, :string)
    field(:html_body, :string)
    field(:sent_at, :utc_datetime)
    embeds_one(:settings, __MODULE__.Settings)
    belongs_to(:sender, Sender, type: Sender.Id)
    belongs_to(:project, Project, type: Project.Id)
    timestamps()
  end

  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:subject, :text_body, :html_body, :sender_id, :project_id])
    |> cast_embed(:settings)
    |> validate_required([:subject, :project_id, :settings])
  end

  def update_changeset(struct = %__MODULE__{}, params) do
    struct
    |> cast(params, [:subject, :text_body, :html_body, :sender_id])
    |> cast_embed(:settings)
    |> validate_required([:subject, :sender_id])
  end
end
