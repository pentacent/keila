defmodule KeilaWeb.CampaignStatsLive do
  use KeilaWeb, :live_view
  require Keila
  alias Keila.{Accounts, Mailings, Tracking}

  on_mount {KeilaWeb.LiveAuth, :require_auth}
  on_mount {KeilaWeb.LiveAuth, :require_project}

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])
    project_id = socket.assigns.current_project.id

    socket =
      assign_new(socket, :campaign, fn ->
        Mailings.get_project_campaign(project_id, session["campaign_id"])
      end)

    if socket.assigns.campaign do
      {:ok, put_initial_assigns(socket)}
    else
      raise KeilaWeb.NotFoundError
    end
  end

  defp put_initial_assigns(socket) do
    campaign = socket.assigns.campaign
    account = Accounts.get_user_account(socket.assigns.current_user.id)
    stats = Mailings.get_campaign_stats(campaign.id)
    link_stats = Tracking.get_link_stats(campaign.id)

    Keila.if_cloud do
      subscription = KeilaCloud.Billing.get_account_subscription(account.id)
    else
      subscription = nil
    end

    socket
    |> assign(:account, account)
    |> assign(:stats, stats)
    |> assign(:chart_datasets, chart_datasets(stats))
    |> assign(:chart_labels, chart_labels(stats))
    |> assign(:link_stats, link_stats)
    |> assign(:subscription, subscription)
    |> schedule_update()
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
