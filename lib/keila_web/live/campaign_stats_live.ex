defmodule KeilaWeb.CampaignStatsLive do
  use KeilaWeb, :live_view
  alias Keila.{Mailings, Tracking}

  @impl true
  def mount(_params, session, socket) do
    project = session["current_project"]
    campaign = session["campaign"]
    stats = Mailings.get_campaign_stats(campaign.id)
    link_stats = Tracking.get_link_stats(campaign.id)
    account = session["account"]
    subscription = Keila.Billing.get_account_subscription(account.id)

    socket =
      socket
      |> assign(:campaign, campaign)
      |> assign(:current_project, project)
      |> assign(:stats, stats)
      |> assign(:account, account)
      |> assign(:subscription, subscription)
      |> assign(:link_stats, link_stats)
      |> put_default_assigns()
      |> schedule_update()

    {:ok, socket}
  end

  defp put_default_assigns(socket) do
    socket
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.CampaignView, "stats_live.html", assigns)
  end

  @impl true
  def handle_info(:update, socket) do
    stats = Mailings.get_campaign_stats(socket.assigns.campaign.id)
    if stats.status != :sent, do: schedule_update(socket)

    {:noreply, assign(socket, :stats, stats)}
  end

  defp schedule_update(socket) do
    Process.send_after(self(), :update, 1000)
    socket
  end
end
