defmodule KeilaWeb.ApiControllerTest do
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

  describe "API is authenticated with Bearer token" do
    @tag :api_controller
    test "requires auth", %{conn: conn, token: token} do
      conn = get(conn, Routes.api_path(conn, :index_contacts))

      assert %{"errors" => [%{"status" => "403", "title" => "Not authorized"}]} =
               json_response(conn, 403)

      conn =
        recycle(conn)
        |> put_req_header("authorization", "Bearer: #{token}")
        |> get(Routes.api_path(conn, :index_contacts))

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/contacts" do
    @tag :api_controller
    test "list contacts", %{authorized_conn: conn, project: project} do
      %{id: contact_id} = insert!(:contact, project_id: project.id)

      conn = get(conn, Routes.api_path(conn, :index_contacts))
      assert %{"data" => [%{"id" => ^contact_id}]} = json_response(conn, 200)
    end

    @tag :api_controller
    test "uses pagination", %{authorized_conn: conn, project: project} do
      insert_n!(:contact, 50, fn _n -> %{project_id: project.id} end)

      page_size = :rand.uniform(25)
      page_count = ceil(50 / page_size)
      page = :rand.uniform(page_count)

      query = %{"paginate" => %{"page" => page, "pageSize" => page_size}}
      conn = get(conn, Routes.api_path(conn, :index_contacts, query))

      assert %{
               "meta" => %{
                 "page" => ^page,
                 "pageCount" => ^page_count,
                 "count" => 50
               },
               "data" => _contacts
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "supports filters", %{authorized_conn: conn, project: project} do
      insert_n!(:contact, 50, fn n ->
        %{project_id: project.id, data: %{"even" => rem(n, 2) == 0}}
      end)

      query = %{"filter" => %{"data.even" => "true"}}
      conn = get(conn, Routes.api_path(conn, :index_contacts, query))

      assert %{
               "meta" => %{
                 "count" => 25
               },
               "data" => [%{"data" => %{"even" => true}} | _]
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "supports filter as string", %{authorized_conn: conn, project: project} do
      insert_n!(:contact, 50, fn n ->
        %{project_id: project.id, data: %{"even" => rem(n, 2) == 0}}
      end)

      query = %{"filter" => Jason.encode!(%{"data.even" => "true"})}
      conn = get(conn, Routes.api_path(conn, :index_contacts, query))

      assert %{
               "meta" => %{
                 "count" => 25
               },
               "data" => [%{"data" => %{"even" => true}} | _]
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "invalid filters create error", %{authorized_conn: conn} do
      query = %{"filter" => "___invalid-filter___"}
      conn = get(conn, Routes.api_path(conn, :index_contacts, query))

      assert %{
               "errors" => _
             } = json_response(conn, 400)

      # TODO check for specific error
    end
  end

  defp put_token_header(conn, token) do
    conn |> put_req_header("authorization", "Bearer: #{token}")
  end
end
