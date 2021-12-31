defmodule KeilaWeb.SegmentControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Auth
  @endpoint KeilaWeb.Endpoint

  describe "GET /projects/:p_id/api_keys" do
    @tag :api_controller_test
    test "has empty state", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.api_key_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first API key"
    end

    @tag :api_controller_test
    test "lists API keys", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      {:ok, key1} = Auth.create_api_key(conn.assigns.current_user.id, project.id, "Foo")
      {:ok, key2} = Auth.create_api_key(conn.assigns.current_user.id, project.id, "Bar")

      conn = get(conn, Routes.api_key_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ ~r{API Keys\s*</h1>}

      for key <- [key1, key2] do
        assert html_response(conn, 200) =~ key.data["name"]
      end
    end
  end

  describe "POST /projects/:p_id/api_keys" do
    @tag :api_controller_test
    test "creates new API key and displays private key", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      conn =
        post(
          conn,
          Routes.api_key_path(conn, :create, project.id, %{"api_key" => %{"name" => "Foo"}})
        )

      assert html_response(conn, 200) =~
               "The private API Key is displayed only once and cannot be recovered."
    end
  end

  describe "DELETE /projects/:p_id/api_keys/:id" do
    @tag :api_controller_test
    test "deletes API key", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      {:ok, token} = Auth.create_api_key(conn.assigns.current_user.id, project.id)

      conn = delete(conn, Routes.api_key_path(conn, :delete, project.id, token.id))

      assert redirected_to(conn, 302) =~ Routes.api_key_path(conn, :index, project.id)
      assert nil == Auth.find_api_key(token.key)
    end
  end
end
