defmodule KeilaWeb.ApiCampaignView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("campaigns.json", %{campaigns: campaigns = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => campaigns.page,
        "page_count" => campaigns.page_count,
        "count" => campaigns.count
      },
      "data" => Enum.map(campaigns.data, &campaign_data/1)
    }
  end

  def render("campaign.json", %{campaign: campaign}) do
    %{
      "data" => campaign_data(campaign)
    }
  end

  def render("delivery_queued.json", %{campaign: campaign}) do
    %{
      "data" => %{
        "delivery_queued" => true,
        "campaign_id" => campaign.id
      }
    }
  end

  @properties [
    :id,
    :subject,
    :text_body,
    :mjml_body,
    :json_body,
    :data,
    :settings,
    :template_id,
    :sender_id,
    :segment_id,
    :sent_at,
    :scheduled_for,
    :updated_at,
    :inserted_at,
    :preview_text
  ]
  @settings_properties [:type]
  defp campaign_data(campaign) do
    campaign
    |> Map.take(@properties)
    |> Map.update!(:settings, &Map.take(&1, @settings_properties))
  end
end
