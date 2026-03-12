defmodule Keila.Tracking.Click do
  use Keila.Schema

  schema "tracking_clicks" do
    belongs_to(:link, Keila.Tracking.Link, type: Keila.Tracking.Link.Id)
    belongs_to(:message, Keila.Mailings.Message, type: Keila.Mailings.Message.Id)

    timestamps(updated_at: false)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:link_id, :message_id])
    |> validate_required([:link_id, :message_id])
  end
end
