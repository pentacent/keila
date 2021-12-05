defmodule KeilaWeb.ApiController do
  use KeilaWeb, :controller

  alias Keila.Auth
  alias Keila.Auth.Token
  alias Keila.Projects
  alias KeilaWeb.ApiNormalizer

  plug :authorize

  plug ApiNormalizer, only: :index_contacts, normalize: [:pagination, :contacts_filter]

  @spec index_contacts(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index_contacts(conn, _params) do
    contacts =
      Keila.Contacts.get_project_contacts(project_id(conn),
        paginate: conn.assigns.pagination,
        filter: conn.assigns.filter
      )

    render(conn, "contacts.json", %{contacts: contacts})
  end

  def create_contact(_conn, _params) do
  end

  def show_contact(_conn, _params) do
  end

  def update_contact(_conn, _params) do
  end

  def delete_contact(_conn, _params) do
  end

  def index_campaigns(_conn, _params) do
  end

  def create_campaign(_conn, _params) do
  end

  def show_campaign(_conn, _params) do
  end

  def update_campaign(_conn, _params) do
  end

  def delete_campaign(_conn, _params) do
  end

  def send_campaign(_conn, _params) do
  end

  def schedule_campaign(_conn, _params) do
  end

  def index_segment(_conn, _params) do
  end

  def create_segment(_conn, _params) do
  end

  def show_segment(_conn, _params) do
  end

  def update_segment(_conn, _params) do
  end

  def delete_segment(_conn, _params) do
  end

  defp project_id(conn), do: conn.assigns.current_project.id

  defp authorize(conn, _) do
    with ["Bearer: " <> token] <- get_req_header(conn, "authorization"),
         %Token{data: %{"project_id" => project_id}, user_id: user_id} <-
           Auth.find_token(token, "api"),
         project = %Projects.Project{} <- Projects.get_user_project(user_id, project_id) do
      conn
      |> assign(:current_project, project)
    else
      _ ->
        conn
        |> put_status(403)
        |> render("not_authorized.json")
        |> halt()
    end
  end
end
