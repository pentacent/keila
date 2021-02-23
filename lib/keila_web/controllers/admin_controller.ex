defmodule KeilaWeb.AdminController do
  use KeilaWeb, :controller
  alias Keila.{Auth, Admin}

  plug :authorize

  @spec dashboard(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dashboard(conn, params) do
    page = String.to_integer(Map.get(params, "page", "1")) - 1
    users = Auth.list_users(paginate: [page: page, page_size: 20])

    conn
    |> put_meta(:title, dgettext("admin", "Admin Dashboard"))
    |> assign(:users, users)
    |> render("dashboard.html")
  end

  @spec delete_users(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_users(conn, params) do
    ids =
      case get_in(params, ["user", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["user", "require_confirmation"]) do
      "true" ->
        render_delete_users_confirmation(conn, ids)

      _ ->
        Enum.each(ids, fn id -> :ok = Admin.purge_user(id) end)
        redirect(conn, to: Routes.admin_path(conn, :dashboard))
    end
  end

  defp render_delete_users_confirmation(conn, ids) do
    users =
      ids
      |> Enum.filter(&(&1 != conn.assigns.current_user.id))
      |> Enum.map(&Keila.Repo.get(Auth.User, &1))

    conn
    |> put_meta(:title, gettext("Confirm User Deletion"))
    |> assign(:users, users)
    |> render("delete_users.html")
  end

  defp authorize(conn, _) do
    case conn.assigns.is_admin? do
      true -> conn
      false -> conn |> put_status(404) |> halt()
    end
  end
end
