defmodule Keila.Tracking.Link do
  use Keila.Schema, prefix: "tl"

  schema "tracking_links" do
    field :url, :string
    belongs_to(:campaign, Keila.Mailings.Campaign, type: Keila.Mailings.Campaign.Id)
    has_many(:clicks, Keila.Tracking.Click)

    timestamps(updated_at: false)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:url, :campaign_id])
    |> validate_required([:url, :campaign_id])
  end
end
