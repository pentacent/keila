defmodule KeilaWeb.ApiCase do
  @moduledoc """

  Helper module for testing API controllers.
  Initializes `:authorized_conn`, `:project`, `:user`, and `:token`.
  Provides `post_json/3` and `patch_json/3` functions for testing calls with
  JSON payload.
  """

  defmacro __using__(_opts) do
    quote do
      use KeilaWeb.ConnCase
      alias Keila.Auth

      setup %{conn: conn} do
        {_root, user} = with_seed()

        {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
        token_params = %{scope: "api", user_id: user.id, data: %{"project_id" => project.id}}
        {:ok, token} = Auth.create_token(token_params)

        authorized_conn = put_token_header(conn, token.key)

        %{user: user, project: project, token: token.key, authorized_conn: authorized_conn}
      end

      def post_json(conn, path, body) do
        conn
        |> put_req_header("content-type", "application/json")
        |> post(path, Jason.encode!(body))
      end

      def patch_json(conn, path, body) do
        conn
        |> put_req_header("content-type", "application/json")
        |> patch(path, Jason.encode!(body))
      end

      def put_token_header(conn, token) do
        conn |> put_req_header("authorization", "Bearer: #{token}")
      end
    end
  end
end
