defmodule KeilaWeb.ApiTemplateController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Templates
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  tags(["Template"])

  operation(:index,
    summary: "Index templates",
    description: "Retrieve all templates from your project.",
    parameters: [],
    responses: [
      ok: {"Template index response", "application/json", Schemas.Template.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    templates =
      Templates.get_project_templates(project_id(conn))
      |> then(fn templates ->
        count = Enum.count(templates)
        %Keila.Pagination{data: templates, page: 0, page_count: 1, count: count}
      end)

    render(conn, "templates.json", %{templates: templates})
  end

  operation(:create,
    summary: "Create Template",
    description: """
    Creates a new template in your project.

    The body field you provide must match the template `type`: `mjml_body` for `mjml` templates, `html_body` for `html` templates, and `text_body` for `text` templates.
    You cannot supply a body field for `hybrid` templates but you may specify `"assigns": {"signature": "your email signature"}`.

    ## Slots
    `mjml`, `html`, and `text` templates support content slots. You may add a content slot by adding
    a `<keila-content name="..."></keila-content>` in the template body. For `mjml` templates, this element
    must be a direct child of `mj-body`.
    """,
    parameters: [],
    request_body: {"Template params", "application/json", Schemas.Template.CreateParams},
    responses: [
      ok: {"Template response", "application/json", Schemas.Template.Response}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    case Templates.create_template(project_id(conn), conn.body_params.data) do
      {:ok, template} -> render(conn, "template.json", %{template: template})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:show,
    summary: "Show Template",
    parameters: [id: [in: :path, type: :string, description: "Template ID"]],
    responses: [
      ok: {"Template response", "application/json", Schemas.Template.Response}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{id: id}) do
    case Templates.get_project_template(project_id(conn), id) do
      template = %Templates.Template{} -> render(conn, "template.json", %{template: template})
      nil -> Errors.send_404(conn)
    end
  end

  operation(:update,
    summary: "Update Template",
    parameters: [id: [in: :path, type: :string, description: "Template ID"]],
    request_body: {"Template params", "application/json", Schemas.Template.UpdateParams},
    responses: [
      ok: {"Template response", "application/json", Schemas.Template.Response}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{id: id}) do
    with template = %Templates.Template{} <- Templates.get_project_template(project_id(conn), id),
         {:ok, template} <- Templates.update_template(template.id, conn.body_params.data) do
      render(conn, "template.json", %{template: template})
    else
      nil -> Errors.send_404(conn)
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:delete,
    summary: "Delete Template",
    parameters: [id: [in: :path, type: :string, description: "Template ID"]],
    responses: %{
      204 => "Template was deleted successfully or didn't exist."
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{id: id}) do
    Templates.delete_project_templates(project_id(conn), [id])

    conn
    |> send_resp(:no_content, "")
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
