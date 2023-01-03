defmodule KeilaWeb.CampaignStatsLive do
  use KeilaWeb, :live_view
  alias Keila.{Mailings, Tracking}

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])

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
      |> assign(:chart_datasets, chart_datasets(stats))
      |> assign(:chart_labels, chart_labels(stats))
      |> assign(:link_stats, link_stats)
      |> assign(:account, account)
      |> assign(:subscription, subscription)
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
    link_stats = Tracking.get_link_stats(socket.assigns.campaign.id)

    if stats.status != :sent, do: schedule_update(socket)

    socket =
      socket
      |> assign(:stats, stats)
      |> assign(:link_stats, link_stats)
      |> assign(:chart_datasets, chart_datasets(stats))
      |> assign(:chart_labels, chart_labels(stats))

    {:noreply, socket}
  end

  defp schedule_update(socket) do
    Process.send_after(self(), :update, 1000)
    socket
  end

  defp chart_datasets(stats) do
    [
      %{
        id: "opens",
        label: gettext("Opens"),
        data: stats[:opened_at_series] |> Enum.map(&elem(&1, 1))
      },
      %{
        id: "clicks",
        label: gettext("Clicks"),
        data: stats[:clicked_at_series] |> Enum.map(&elem(&1, 1))
      }
    ]
    |> Jason.encode!()
  end

  defp chart_labels(stats) do
    stats[:opened_at_series] |> Enum.map(&elem(&1, 0)) |> Jason.encode!()
  end
end
