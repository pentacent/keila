defmodule KeilaWeb.CampaignIndexLive do
  use KeilaWeb, :live_view
  alias Keila.Mailings

  @page_size 12

  on_mount {KeilaWeb.LiveAuth, :require_auth}
  on_mount {KeilaWeb.LiveAuth, :require_project}

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])

    socket =
      socket
      |> assign(:campaigns_status, session["campaigns_status"])
      |> put_initial_assigns()

    {:ok, socket}
  end

  defp put_initial_assigns(socket) do
    project_id = socket.assigns.current_project.id

    socket
    |> assign(:campaigns_counts, Mailings.get_project_campaigns_counts(project_id))
    |> assign(:search, "")
    |> assign(:page, 0)
    |> put_campaigns()
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.CampaignView, "index_live.html", assigns)
  end

  @impl true
  def handle_event("change-status", %{"status" => status}, socket)
      when status in ["draft", "scheduled", "sent"] do
    campaigns_status = String.to_existing_atom(status)

    socket =
      socket
      |> assign(:campaigns_status, campaigns_status)
      |> assign(:search, "")
      |> assign(:page, 0)
      |> put_campaigns()
      |> push_event("replace-url", %{
        url: index_path(socket.assigns.current_project.id, campaigns_status)
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign(:search, search)
      |> assign(:page, 0)
      |> put_campaigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change-page", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:page, String.to_integer(page))
      |> put_campaigns()
      |> push_event("scroll-top", %{})

    {:noreply, socket}
  end

  defp index_path(project_id, :draft), do: ~p"/projects/#{project_id}/campaigns"
  defp index_path(project_id, :scheduled), do: ~p"/projects/#{project_id}/campaigns/scheduled"
  defp index_path(project_id, :sent), do: ~p"/projects/#{project_id}/campaigns/sent"

  defp put_campaigns(socket) do
    search = String.trim(socket.assigns.search)
    selected_status = if search == "", do: socket.assigns.campaigns_status

    campaigns =
      Mailings.get_project_campaigns(socket.assigns.current_project.id,
        status: selected_status,
        search: search,
        paginate: [page: socket.assigns.page, page_size: @page_size]
      )

    socket
    |> assign(:selected_status, selected_status)
    |> assign(:campaigns, campaigns)
  end
end
