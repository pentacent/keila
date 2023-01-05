defmodule KeilaWeb.ApiSenderControllerTest do
  use KeilaWeb.ApiCase

  describe "API is authenticated with Bearer token" do
    @tag :api_sender_controller
    test "requires auth", %{conn: conn, token: token} do
      conn = get(conn, Routes.api_sender_path(conn, :index))

      assert %{"errors" => [%{"status" => "403", "title" => "Not authorized"}]} =
               json_response(conn, 403)

      conn =
        recycle(conn)
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(Routes.api_sender_path(conn, :index))

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/senders" do
    @tag :api_contact_controller
    test "list senders", %{authorized_conn: conn, project: project} do
      %{id: sender_id} = insert!(:mailings_sender, project_id: project.id)

      conn = get(conn, Routes.api_sender_path(conn, :index))
      assert %{"data" => [%{"id" => ^sender_id}]} = json_response(conn, 200)
    end
  end
end
