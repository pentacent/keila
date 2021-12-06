defmodule KeilaWeb.ApiController do
  use KeilaWeb, :controller

  alias Keila.Auth
  alias Keila.Auth.Token
  alias Keila.Projects
  alias KeilaWeb.ApiNormalizer
  alias Keila.Contacts

  plug :authorize

  plug ApiNormalizer, [normalize: [:pagination, :contacts_filter]] when action == :index_contacts

  plug ApiNormalizer,
       [normalize: [:contact_data]] when action in [:create_contact, :update_contact]

  @spec index_contacts(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index_contacts(conn, _params) do
    contacts =
      Contacts.get_project_contacts(project_id(conn),
        paginate: conn.assigns.pagination,
        filter: conn.assigns.filter
      )

    render(conn, "contacts.json", %{contacts: contacts})
  end

  def create_contact(conn, _params) do
    case Contacts.create_contact(project_id(conn), conn.assigns.data) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> send_changeset_error(conn, changeset)
    end
  end

  def show_contact(conn, %{"id" => id}) do
    case Contacts.get_project_contact(project_id(conn), id) do
      contact = %Contacts.Contact{} -> render(conn, "contact.json", %{contact: contact})
      nil -> send_404(conn)
    end
  end

  def update_contact(conn, %{"id" => id}) do
    if Contacts.get_project_contact(project_id(conn), id) do
      case Contacts.update_contact(id, conn.assigns.data) do
        {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
        {:error, changeset} -> send_changeset_error(conn, changeset)
      end
    else
      send_404(conn)
    end
  end

  def delete_contact(conn, %{"id" => id}) do
    Contacts.delete_project_contacts(project_id(conn), filter: %{"id" => id})

    conn
    |> put_status(204)
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

  defp send_403(conn) do
    conn
    |> put_status(403)
    |> render("errors.json", %{errors: [[status: 403, title: "Not authorized"]]})
  end

  defp send_404(conn) do
    conn
    |> put_status(404)
    |> render("errors.json", %{errors: [[status: 404, title: "Not found"]]})
  end

  defp send_changeset_error(conn, changeset) do
    conn
    |> put_status(400)
    |> render("errors.json", %{errors: [[status: 400, detail: changeset]]})
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
      _ -> conn |> send_403() |> halt()
    end
  end
end
