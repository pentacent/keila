defmodule KeilaWeb.ApiKeyController do
  use KeilaWeb, :controller
  alias Keila.Auth

  def index(conn, _params) do
    tokens = Auth.get_user_project_api_keys(current_user(conn).id, current_project(conn).id)

    conn
    |> assign(:tokens, tokens)
    |> render("index.html")
  end

  def new(conn, _params) do
    conn
    |> render("new.html")
  end

  def create(conn, params) do
    name = params["api_key"]["name"]
    {:ok, token} = Auth.create_api_key(current_user(conn).id, current_project(conn).id, name)
    tokens = Auth.get_user_project_api_keys(current_user(conn).id, current_project(conn).id)

    conn
    |> assign(:token, token)
    |> assign(:tokens, tokens)
    |> render("index.html")
  end

  def delete(conn, %{"id" => id}) do
    Auth.delete_project_api_key(current_project(conn).id, id)

    conn
    |> redirect(to: Routes.api_key_path(conn, :index, current_project(conn).id))
  end

  defp current_project(conn), do: conn.assigns.current_project
  defp current_user(conn), do: conn.assigns.current_user
end
