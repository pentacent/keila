defmodule KeilaWeb.Api.Plugs.Authorization do
  @behaviour Plug
  import Plug.Conn
  alias Keila.Auth
  alias Keila.Projects

  def init(_), do: nil

  def call(conn, _) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %Auth.Token{data: %{"project_id" => project_id}, user_id: user_id} <-
           Auth.find_token(token, "api"),
         project = %Projects.Project{} <-
           Projects.get_user_project(user_id, project_id) do
      conn
      |> assign(:current_project, project)
    else
      _ -> conn |> KeilaWeb.Api.Errors.send_403() |> halt()
    end
  end
end
