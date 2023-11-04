defmodule KeilaWeb.SegmentController do
  use KeilaWeb, :controller
  alias Keila.{Contacts, Contacts.Segment}
  import Ecto.Changeset
  import Phoenix.LiveView.Controller

  plug(:authorize when action not in [:index, :new, :create, :delete])

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    segments = Contacts.get_project_segments(current_project(conn).id)

    conn
    |> assign(:segments, segments)
    |> render("index.html")
  end

  def new(conn, _params) do
    conn
    |> assign(:changeset, change(%Segment{}))
    |> render("new.html")
  end

  def create(conn, %{"segment" => params}) do
    project = current_project(conn)

    with {:ok, segment = %Segment{}} <- Contacts.create_segment(project.id, params) do
      redirect(conn, to: Routes.segment_path(conn, :edit, project.id, segment.id))
    else
      {:error, changeset} -> conn |> assign(:changeset, changeset) |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    live_render(conn, KeilaWeb.SegmentEditLive,
      session: %{
        "current_project" => current_project(conn),
        "segment" => conn.assigns.segment,
        "locale" => Gettext.get_locale()
      }
    )
  end

  def delete(conn, params) do
    ids =
      case get_in(params, ["segment", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["segment", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        :ok = Contacts.delete_project_segments(current_project(conn).id, ids)

        redirect(conn, to: Routes.segment_path(conn, :index, current_project(conn).id))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    segments =
      Contacts.get_project_segments(current_project(conn).id)
      |> Enum.filter(&(&1.id in ids))

    conn
    |> put_meta(:title, gettext("Confirm Segment Deletion"))
    |> assign(:segments, segments)
    |> render("delete.html")
  end

  @spec contacts_export(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def contacts_export(conn, %{"project_id" => project_id, "id" => segment_id}) do
    filename = "contacts_#{project_id}_segment_#{segment_id}.csv"

    filter = conn.assigns.segment.filter || %{}
    KeilaWeb.ContactsCsvExport.stream_csv_response(conn, filename, project_id, filter: filter)
  end

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    segment_id = conn.path_params["id"]

    case Contacts.get_project_segment(project_id, segment_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      segment ->
        assign(conn, :segment, segment)
    end
  end
end
