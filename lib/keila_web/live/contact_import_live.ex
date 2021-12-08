defmodule KeilaWeb.ContactImportLive do
  use KeilaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> allow_upload(:csv, accept: [".csv", ".txt", ".tsv"], max_entries: 1)
      |> assign(:uploaded_files, [])
      |> assign(:current_project, session["current_project"])
      |> put_default_assigns()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.ContactView, "import_live.html", assigns)
  end

  @impl true
  def handle_event("validate", %{"import" => import_options}, socket) do
    {:noreply, assign(socket, :import_replace, import_options["replace"] == "true")}
  end

  def handle_event("import", %{"import" => import_options}, socket) do
    [{csv_filename, import_task}] =
      consume_uploaded_entries(socket, :csv, fn %{path: upload_path}, _entry ->
        pid = self()

        csv_basename =
          socket.assigns.current_project.id <>
            Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false) <> "_import.csv"

        csv_filename = Path.join(System.tmp_dir!(), csv_basename)
        File.cp!(upload_path, csv_filename)

        on_conflict = if import_options["replace"] == "true", do: :replace, else: :ignore

        task =
          Task.async(fn ->
            Keila.Contacts.import_csv(socket.assigns.current_project.id, csv_filename,
              notify: pid,
              on_conflict: on_conflict
            )
          end)

        {csv_filename, task}
      end)

    socket =
      socket
      |> assign(:csv_filename, csv_filename)
      |> assign(:import_task, import_task)
      |> put_default_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:contacts_import_progress, progress, total}, socket) do
    socket =
      socket
      |> assign(:import_progress, progress)
      |> assign(:import_total, total)

    {:noreply, socket}
  end

  def handle_info({reference, {:error, reason}}, socket) when is_reference(reference) do
    File.rm(socket.assigns.csv_filename)
    {:noreply, assign(socket, :import_error, reason)}
  end

  def handle_info({reference, :ok}, socket) when is_reference(reference) do
    File.rm(socket.assigns.csv_filename)

    {:noreply, socket}
  end

  def handle_info({:DOWN, reference, :process, _, :normal}, socket)
      when is_reference(reference) do
    File.rm(socket.assigns.csv_filename)

    {:noreply, socket}
  end

  @impl true
  def terminate(:normal, socket) do
    if socket.assigns.csv_filename do
      File.rm(socket.assigns.csv_filename)
    end
  end

  defp put_default_assigns(socket) do
    socket
    |> assign(:import_progress, 0)
    |> assign(:import_total, 0)
    |> assign(:import_error, nil)
    |> assign(:import_replace, true)
  end
end
