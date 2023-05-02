defmodule KeilaWeb.TemplateController do
  use KeilaWeb, :controller
  alias Keila.Templates
  alias Keila.Templates.Template
  alias Keila.Templates.HybridTemplate
  import Ecto.Changeset
  import Phoenix.LiveView.Controller

  plug :authorize when action not in [:index, :new, :post_new, :delete]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    templates = Templates.get_project_templates(current_project(conn).id)

    conn
    |> assign(:templates, templates)
    |> put_meta(:title, gettext("Templates"))
    |> render("index.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    render_new(conn, change(%Template{}))
  end

  @spec post_new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_new(conn, params) do
    project = current_project(conn)

    params =
      (params["template"] || %{})
      |> Map.put("assigns", %{"signature" => HybridTemplate.signature()})

    case Templates.create_template(project.id, params) do
      {:ok, template} ->
        redirect(conn, to: Routes.template_path(conn, :edit, project.id, template.id))

      {:error, changeset} ->
        render_new(conn, 400, changeset)
    end
  end

  defp render_new(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> put_meta(:title, gettext("New Template"))
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  @spec clone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def clone(conn, _params) do
    render_clone(conn, change(conn.assigns.template))
  end

  @spec post_clone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_clone(conn, params) do
    project = current_project(conn)
    template = conn.assigns.template
    params = params["template"] || %{}

    case Templates.clone_template(template.id, params) do
      {:ok, template} ->
        redirect(conn, to: Routes.template_path(conn, :edit, project.id, template.id))

      {:error, changeset} ->
        render_clone(conn, 400, changeset)
    end
  end

  defp render_clone(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Clone Template"))
    |> assign(:changeset, changeset)
    |> render("clone.html")
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    project = current_project(conn)
    template = conn.assigns.template

    live_render(conn, KeilaWeb.TemplateEditLive,
      session: %{
        "current_project" => project,
        "template" => template,
        "locale" => Gettext.get_locale()
      }
    )
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, %{"template" => params}) do
    project = current_project(conn)
    template = conn.assigns.template
    styles = fetch_styles(params)

    case Templates.update_template(template.id, Map.put(params, "styles", styles)) do
      {:ok, _template} ->
        redirect(conn, to: Routes.template_path(conn, :index, project.id))

      {:error, changeset} ->
        live_render(conn, KeilaWeb.TemplateEditLive,
          session: %{
            "current_project" => project,
            "template" => template,
            "changeset" => changeset,
            "locale" => Gettext.get_locale()
          }
        )
    end
  end

  defp fetch_styles(params) do
    if is_map(params["styles"]) do
      Keila.Templates.HybridTemplate.style_template()
      |> Keila.Templates.StyleTemplate.apply_values_from_params(params["styles"])
      |> Keila.Templates.StyleTemplate.to_css()
      |> Keila.Templates.Css.encode()
    else
      params["styles"]
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    ids =
      case get_in(params, ["template", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["template", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        :ok = Templates.delete_project_templates(current_project(conn).id, ids)

        redirect(conn, to: Routes.template_path(conn, :index, current_project(conn).id))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    templates =
      Templates.get_project_templates(current_project(conn).id)
      |> Enum.filter(&(&1.id in ids))

    conn
    |> put_meta(:title, gettext("Confirm Template Deletion"))
    |> assign(:templates, templates)
    |> render("delete.html")
  end

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    template_id = conn.path_params["id"]

    case Templates.get_project_template(project_id, template_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      template ->
        assign(conn, :template, template)
    end
  end
end
