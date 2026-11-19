defmodule KeilaWeb.TemplateEditLive do
  use KeilaWeb, :live_view
  alias Keila.Templates.{Template, StyleTemplate, HybridTemplate}

  on_mount {KeilaWeb.LiveAuth, :require_auth}
  on_mount {KeilaWeb.LiveAuth, :require_project}

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])
    project_id = socket.assigns.current_project.id

    socket =
      assign_new(socket, :template, fn ->
        Keila.Templates.get_project_template(project_id, session["template_id"])
      end)

    if socket.assigns.template do
      {:ok, put_initial_assigns(socket)}
    else
      raise KeilaWeb.NotFoundError
    end
  end

  defp put_initial_assigns(socket) do
    template = socket.assigns.template
    styles = if template.type == :hybrid, do: Keila.Templates.Css.parse!(template.styles || "")

    style_template =
      if template.type == :hybrid,
        do:
          HybridTemplate.style_template()
          |> StyleTemplate.apply_values_from_css(styles)

    socket
    |> assign(:changeset, Ecto.Changeset.change(template))
    |> assign(:style_template, style_template)
    |> put_template_preview()
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.TemplateView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", %{"template" => params}, socket) do
    changeset =
      Template.update_changeset(
        socket.assigns.template,
        Map.delete(params, "styles")
      )

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:style_template, style_template_from_params(socket, params))
      |> put_template_preview()

    {:noreply, socket}
  end

  def handle_event("save", %{"template" => params}, socket) do
    params = Map.put(params, "styles", styles_from_params(params))

    case Keila.Templates.update_template(socket.assigns.template.id, params) do
      {:ok, _template} ->
        project_id = socket.assigns.current_project.id
        {:noreply, redirect(socket, to: Routes.template_path(socket, :index, project_id))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp style_template_from_params(socket, params) do
    if socket.assigns.template.type == :hybrid,
      do: StyleTemplate.apply_values_from_params(socket.assigns.style_template, params["styles"])
  end

  defp styles_from_params(params) do
    if is_map(params["styles"]) do
      HybridTemplate.style_template()
      |> StyleTemplate.apply_values_from_params(params["styles"])
      |> StyleTemplate.to_css()
      |> Keila.Templates.Css.encode()
    else
      params["styles"]
    end
  end

  defp put_template_preview(socket) do
    {:ok, template} = Ecto.Changeset.apply_action(socket.assigns.changeset, :update)
    preview = KeilaWeb.TemplateView.render_preview(template, socket.assigns.style_template)

    assign(socket, :preview, preview)
  end
end
