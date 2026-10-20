defmodule KeilaWeb.EmailDialogLiveComponent do
  @moduledoc """
  Dialog for editing a `Keila.Mailings.Email` with settings and the
  `KeilaWeb.EmailEditorLiveComponent`.

  Opened with `phx-click="open" phx-target="#<id>"`. Confirming a valid
  email closes the dialog and sends `{:email_dialog, id, params}` to the
  parent, which applies the params to `email`.

  The parent must render `_wysiwyg_dialogs.html` and `_preview_dialog.html`
  from `KeilaWeb.EmailEditorView` once per page.

  ## Assigns

  * `id`
  * `email` - email to edit
  * `title`
  * `project_id` - used to fetch the selected template
  * `templates` - selectable templates
  * `changeset_opts` - options for `Keila.Mailings.Email.changeset/3`
  * `subject_placeholder`
  * `body_placeholder` - placeholder of the plain Markdown editor
  * `preview_assigns` - assigns for the preview
  * `preprocess_preview` - applied to the email before rendering the preview

  ## Slots

  * `help` - help text shown above the editor
  """
  use KeilaWeb, :live_component

  alias Keila.Mailings.Email

  @impl true
  def mount(socket) do
    {:ok, assign(socket, tab: nil, changeset: nil)}
  end

  @impl true
  def update(%{editor_params: params}, socket) do
    {:ok, change(socket, params)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:changeset_opts, fn -> [] end)
      |> assign_new(:subject_placeholder, fn -> nil end)
      |> assign_new(:body_placeholder, fn -> nil end)
      |> assign_new(:preview_assigns, fn -> %{} end)
      |> assign_new(:preprocess_preview, fn -> &Function.identity/1 end)
      |> assign_new(:help, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.EmailDialogView, "email_dialog.html", assigns)
  end

  @impl true
  def handle_event("open", _params, socket) do
    %{email: email, changeset_opts: changeset_opts} = socket.assigns
    changeset = Email.changeset(email, %{}, changeset_opts)
    tab = if email.subject || email.template_id, do: :content, else: :settings

    {:noreply, assign(socket, tab: tab, changeset: changeset)}
  end

  def handle_event("change", %{"email" => params}, socket) do
    {:noreply, change(socket, params)}
  end

  def handle_event("show_content", _params, socket) do
    {:noreply, assign(socket, :tab, :content)}
  end

  def handle_event("show_settings", _params, socket) do
    {:noreply, assign(socket, :tab, :settings)}
  end

  def handle_event("confirm", %{"email" => params}, socket) do
    socket = change(socket, params)

    case Ecto.Changeset.apply_action(socket.assigns.changeset, :update) do
      {:ok, _email} ->
        send(self(), {:email_dialog, socket.assigns.id, socket.assigns.changeset.params})
        {:noreply, close(socket)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, close(socket)}
  end

  defp change(socket, params) do
    %{changeset: changeset, changeset_opts: changeset_opts} = socket.assigns
    params = Map.merge(changeset.params, params)

    assign(socket, :changeset, Email.changeset(changeset.data, params, changeset_opts))
  end

  defp close(socket) do
    assign(socket, :changeset, nil)
  end
end
