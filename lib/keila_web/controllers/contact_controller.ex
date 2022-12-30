defmodule KeilaWeb.ContactController do
  use KeilaWeb, :controller
  import Phoenix.LiveView.Controller
  import Ecto.Changeset
  alias Keila.Contacts

  plug :authorize
       when action not in [
              :index,
              :index_unsubscribed,
              :index_unreachable,
              :new,
              :post_new,
              :delete,
              :import
            ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    conn
    |> put_meta(:title, gettext("Contacts"))
    |> assign(:contacts_status, :active)
    |> do_index(params)
  end

  @spec index_unsubscribed(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index_unsubscribed(conn, params) do
    conn
    |> put_meta(:title, gettext("Unsubscribed Contacts"))
    |> assign(:contacts_status, :unsubscribed)
    |> do_index(params)
  end

  @spec index_unreachable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index_unreachable(conn, params) do
    conn
    |> put_meta(:title, gettext("Unsubscribed Contacts"))
    |> assign(:contacts_status, :unreachable)
    |> do_index(params)
  end

  defp do_index(conn, params) do
    project_id = current_project(conn).id

    page = String.to_integer(Map.get(params, "page", "1")) - 1
    filter = %{"status" => conn.assigns.contacts_status |> to_string()}
    query_opts = [filter: filter, paginate: [page: page, page_size: 50]]
    contacts = Contacts.get_project_contacts(project_id, query_opts)
    contacts_stats = Contacts.get_project_contacts_stats(project_id)

    conn
    |> assign(:contacts, contacts)
    |> assign(:contacts_stats, contacts_stats)
    |> render("index.html")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    ids =
      case get_in(params, ["contact", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["contact", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        opts = [filter: %{"id" => %{"$in" => ids}}, sort: false]
        :ok = Contacts.delete_project_contacts(current_project(conn).id, opts)

        redirect(conn, to: Routes.contact_path(conn, :index, current_project(conn).id))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    contacts =
      Contacts.get_project_contacts(current_project(conn).id, filter: %{"id" => %{"$in" => ids}})

    conn
    |> put_meta(:title, gettext("Confirm Contact Deletion"))
    |> assign(:contacts, contacts)
    |> render("delete.html")
  end

  @spec import(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import(conn, _params) do
    live_render(conn, KeilaWeb.ContactImportLive,
      session: %{
        "current_project" => conn.assigns.current_project,
        "locale" => Gettext.get_locale()
      }
    )
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    render_edit(conn, change(%Contacts.Contact{}))
  end

  @spec post_new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_new(conn, params) do
    params = params["contact"] || %{}

    case Contacts.create_contact(current_project(conn).id, params) do
      {:ok, %{id: id}} ->
        Keila.Tracking.log_event("create", id, %{})
        redirect(conn, to: Routes.contact_path(conn, :index, current_project(conn).id))

      {:error, changeset} ->
        render_edit(conn, 400, changeset)
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _) do
    changeset =
      conn.assigns.contact
      |> change()

    events = Keila.Tracking.get_contact_events(conn.assigns.contact.id)

    data =
      case get_field(changeset, :data) do
        nil -> nil
        data -> Jason.encode!(data)
      end

    conn
    |> assign(:events, events)
    |> assign(:data, data)
    |> render_edit(changeset)
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, %{"contact" => params}) do
    contact = conn.assigns.contact

    with {:ok, _} <- Contacts.update_contact(contact.id, params) do
      redirect(conn, to: Routes.contact_path(conn, :index, current_project(conn).id))
    else
      {:error, changeset} -> render_edit(conn, 400, changeset)
    end
  end

  defp render_edit(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Edit Contact"))
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    contact_id = conn.path_params["id"]

    case Contacts.get_project_contact(project_id, contact_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      contact ->
        assign(conn, :contact, contact)
    end
  end
end
