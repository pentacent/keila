defmodule KeilaWeb.AccountController do
  use KeilaWeb, :controller
  import Ecto.Changeset
  alias Keila.Auth

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _) do
    render_edit(conn, change(conn.assigns.current_user))
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, params) do
    params = Map.get(params, "user", %{})

    case Auth.update_user_password(conn.assigns.current_user.id, params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, dgettext("auth", "New password saved."))
        |> render_edit(change(user))

      {:error, changeset} ->
        render_edit(conn, changeset)
    end
  end

  defp render_edit(conn, changeset) do
    conn
    |> put_meta(:title, dgettext("auth", "Manage Account"))
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end
end
