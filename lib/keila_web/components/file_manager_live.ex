defmodule KeilaWeb.FileManagerLiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:files, accept: ~w(.jpg .jpeg .png .gif .webp))
     |> assign(:files, [])
     |> assign(:page, 0)}
  end

  @impl true
  @spec update(any, any) :: none
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> put_files()}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.ComponentView, "file_manager_live.html", assigns)
  end

  @impl true
  def handle_event("validate-upload", _, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _, socket) do
    consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
      meta = [filename: entry.client_name, type: entry.client_type]

      Keila.Files.store_file(socket.assigns.current_project_id, path, meta)
    end)

    {:noreply, socket |> put_files()}
  end

  def handle_event("delete_upload", %{"id" => file_uuid}, socket) do
    project_id = socket.assigns.current_project_id
    campaign_id = socket.assigns[:current_campaign_id]

    case Keila.Files.get_project_file(project_id, file_uuid) do
      nil ->
        {:noreply, socket}

      file ->
        file_url = Keila.Files.get_file_url(file.uuid)

        campaigns =
          Keila.Mailings.search_in_project_campaigns(project_id, file_url)
          |> Enum.filter(fn campaign -> is_nil(campaign_id) or campaign.id != campaign_id end)

        case campaigns do
          [] ->
            case Keila.Files.delete_file(file.uuid) do
              :ok ->
                {:noreply,
                 socket
                 |> push_event("remove_file", %{id: file_uuid, src: file_url})
                 |> put_files()}

              {:error, _} ->
                {:noreply, socket}
            end

          campaigns ->
            campaign_details =
              Enum.map(campaigns, fn campaign ->
                %{
                  id: campaign.id,
                  subject: campaign.subject,
                  status: if(campaign.sent_at, do: "sent", else: "draft")
                }
              end)

            {:noreply,
             push_event(socket, "file_in_use", %{campaigns: campaign_details, id: file_uuid})}
        end
    end
  end

  def handle_event("change-page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> put_files()

    {:noreply, socket}
  end

  defp put_files(socket) do
    project_id = socket.assigns.current_project_id

    files =
      Keila.Files.get_project_files(project_id,
        paginate: [page_size: 4, page: socket.assigns.page]
      )

    file_urls =
      files.data
      |> Enum.map(fn file ->
        Keila.Files.get_file_url(file.uuid)
      end)

    socket
    |> assign(:files, files)
    |> assign(:file_urls, file_urls)
  end
end
