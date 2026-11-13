defmodule KeilaWeb.Api.Plugs.Authorization do
  @behaviour Plug
  import Plug.Conn
  alias Keila.Auth
  alias Keila.Projects

  def init(_), do: nil

  def call(conn, _) do
    with ["Bearer " <> api_key] <- get_req_header(conn, "authorization"),
         {:ok, project} <- fetch_project(api_key) do
      assign(conn, :current_project, project)
    else
      {:error, :invalid_api_key} ->
        conn
        |> KeilaWeb.AuthEvents.log_auth_event(:authenticate_api_failed, nil)
        |> KeilaWeb.Api.Errors.send_403()
        |> halt()

      _ ->
        conn |> KeilaWeb.Api.Errors.send_403() |> halt()
    end
  end

  defp fetch_project(api_key) do
    with %Auth.Token{data: %{"project_id" => project_id}, user_id: user_id} <-
           Auth.find_api_key(api_key),
         project = %Projects.Project{} <-
           Projects.get_user_project(user_id, project_id) do
      {:ok, project}
    else
      _ -> {:error, :invalid_api_key}
    end
  end
end
