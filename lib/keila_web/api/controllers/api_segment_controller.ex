defmodule KeilaWeb.ApiSegmentController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Contacts
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  tags(["Segment"])

  operation(:index,
    summary: "Index segments",
    description: "Retrieve all segments from your project.",
    parameters: [],
    responses: [
      ok: {"Segment response", "application/json", Schemas.ContactsSegment.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    segments =
      Contacts.get_project_segments(project_id(conn))
      |> then(fn segments ->
        count = Enum.count(segments)
        %Keila.Pagination{data: segments, page: 0, page_count: 1, count: count}
      end)

    render(conn, "segments.json", %{segments: segments})
  end

  operation(:create,
    summary: "Create Segment",
    parameters: [],
    request_body: {"Segment params", "application/json", Schemas.ContactsSegment.Params},
    responses: [
      ok: {"Segment response", "application/json", Schemas.ContactsSegment.Response}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    case Contacts.create_segment(project_id(conn), conn.body_params.data) do
      {:ok, segment} -> render(conn, "segment.json", %{segment: segment})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:show,
    summary: "Show Segment",
    parameters: [id: [in: :path, type: :string, description: "Segment ID"]],
    responses: [
      ok: {"Segment response", "application/json", Schemas.ContactsSegment.Response}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{id: id}) do
    case Contacts.get_project_segment(project_id(conn), id) do
      segment = %Contacts.Segment{} -> render(conn, "segment.json", %{segment: segment})
      nil -> Errors.send_404(conn)
    end
  end

  operation(:update,
    summary: "Update Segment",
    parameters: [id: [in: :path, type: :string, description: "Segment ID"]],
    request_body: {"Segment params", "application/json", Schemas.ContactsSegment.Params},
    responses: [
      ok: {"Segment response", "application/json", Schemas.ContactsSegment.Response}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{id: id}) do
    if Contacts.get_project_segment(project_id(conn), id) do
      case Contacts.update_segment(id, conn.body_params.data) do
        {:ok, segment} -> render(conn, "segment.json", %{segment: segment})
        {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
      end
    else
      Errors.send_404(conn)
    end
  end

  operation(:delete,
    summary: "Delete Segment",
    parameters: [id: [in: :path, type: :string, description: "Segment ID"]],
    responses: %{
      204 => "Segment was deleted successfully or didn’t exist."
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{id: id}) do
    Contacts.delete_project_segments(project_id(conn), [id])

    conn
    |> put_status(204)
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
