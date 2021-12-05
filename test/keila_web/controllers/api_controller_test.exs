defmodule KeilaWeb.ApiControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Auth

  setup do
    {_root, user} = with_seed()
    %{user: user}
  end

  describe "API is authenticated with Bearer token" do
    @tag :api_controller
    test "requires auth", %{conn: conn, user: user} do
      conn = get(conn, Routes.api_path(conn, :index_contacts))

      assert %{"errors" => [%{"status" => "403", "title" => "Not authorized"}]} =
               json_response(conn, 403)

      {_project, token} = create_api_project_token(user)

      conn =
        recycle(conn)
        |> put_req_header("authorization", "Bearer: #{token}")
        |> get(Routes.api_path(conn, :index_contacts))

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/contacts" do
    @tag :api_controller
    test "list contacts", %{conn: conn, user: user} do
      {project, token} = create_api_project_token(user)
      %{id: contact_id} = insert!(:contact, project_id: project.id)

      conn = conn |> put_token_header(token) |> get(Routes.api_path(conn, :index_contacts))
      assert %{"data" => [%{"id" => ^contact_id}]} = json_response(conn, 200)
    end

    @tag :api_controller
    test "uses pagination", %{conn: conn, user: user} do
      {project, token} = create_api_project_token(user)
      insert_n!(:contact, 50, fn _n -> %{project_id: project.id} end)

      page_size = :rand.uniform(25)
      page_count = ceil(50 / page_size)
      page = :rand.uniform(page_count)

      query = %{
        "paginate" => %{
          "page" => page,
          "pageSize" => page_size
        }
      }

      conn = conn |> put_token_header(token) |> get(Routes.api_path(conn, :index_contacts, query))

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
    test "supports filters", %{conn: conn, user: user} do
      {project, token} = create_api_project_token(user)

      insert_n!(:contact, 50, fn n ->
        %{project_id: project.id, data: %{"even" => rem(n, 2) == 0}}
      end)

      query = %{
        "filter" => %{
          "data.even" => "true"
        }
      }

      conn = conn |> put_token_header(token) |> get(Routes.api_path(conn, :index_contacts, query))

      assert %{
               "meta" => %{
                 "count" => 25
               },
               "data" => [%{"data" => %{"even" => true}} | _]
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "supports filter as string", %{conn: conn, user: user} do
      {project, token} = create_api_project_token(user)

      insert_n!(:contact, 50, fn n ->
        %{project_id: project.id, data: %{"even" => rem(n, 2) == 0}}
      end)

      query = %{
        "filter" =>
          Jason.encode!(%{
            "data.even" => "true"
          })
      }

      conn = conn |> put_token_header(token) |> get(Routes.api_path(conn, :index_contacts, query))

      assert %{
               "meta" => %{
                 "count" => 25
               },
               "data" => [%{"data" => %{"even" => true}} | _]
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "invalid filters create error", %{conn: conn, user: user} do
      {_project, token} = create_api_project_token(user)
      query = %{"filter" => "___invalid-filter___"}
      conn = conn |> put_token_header(token) |> get(Routes.api_path(conn, :index_contacts, query))

      assert %{
               "errors" => _
             } = json_response(conn, 400)

      # TODO check for specific error
    end
  end

  defp create_api_project_token(user) do
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    token_params = %{scope: "api", user_id: user.id, data: %{"project_id" => project.id}}
    {:ok, token} = Auth.create_token(token_params)

    {project, token.key}
  end

  defp put_token_header(conn, token) do
    conn |> put_req_header("authorization", "Bearer: #{token}")
  end
end
