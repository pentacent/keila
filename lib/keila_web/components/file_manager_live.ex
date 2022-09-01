defmodule KeilaWeb.FileManagerLiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:files, accept: ~w(.jpg .jpeg .png .gif))
     |> assign(:files, [])
     |> assign(:page, 0)}
  end

  @impl true
  def update(assigns, socket) do
    IO.inspect(assigns)

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
      IO.inspect(entry)
      meta = [filename: entry.client_name, type: entry.client_type]

      Keila.Files.store_file(socket.assigns.current_project_id, path, meta)
    end)

    {:noreply, socket |> put_files()}
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
