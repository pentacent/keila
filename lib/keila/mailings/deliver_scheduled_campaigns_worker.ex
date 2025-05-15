defmodule Keila.Mailings.DeliverScheduledCampaignsWorker do
  use Oban.Worker, queue: :mailer_scheduler
  alias Keila.Mailings

  def perform(%Oban.Job{}) do
    Mailings.get_campaigns_to_be_delivered(DateTime.utc_now())
    |> Enum.each(fn c ->
      Mailings.deliver_campaign_async(c.id)
    end)
  end
end
