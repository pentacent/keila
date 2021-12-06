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
               "errors" => [%{"title" => "Invalid JSON"}]
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/contacts" do
    @tag :api_controller
    test "creates contact", %{authorized_conn: conn} do
      params = %{"email" => "api@example.com", "firstName" => "Jane", "lastName" => "API"}
      conn = post(conn, Routes.api_path(conn, :create_contact, data: params))

      assert %{
               "data" => %{
                 "email" => "api@example.com",
                 "firstName" => "Jane",
                 "lastName" => "API"
               }
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "renders changeset error", %{authorized_conn: conn} do
      params = %{"email" => "__invalid__email"}
      conn = post(conn, Routes.api_path(conn, :create_contact, data: params))

      assert %{"errors" => errors} = json_response(conn, 400)

      assert Enum.find(errors, fn error ->
               match?(%{"pointer" => "/data/attributes/email"}, error)
             end)
    end
  end

  describe "GET /api/v1/contacts/:id" do
    @tag :api_controller
    test "retrieves contact", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      %{email: email, first_name: first_name, last_name: last_name} = contact

      conn = get(conn, Routes.api_path(conn, :show_contact, contact.id))

      assert %{
               "data" => %{
                 "email" => ^email,
                 "firstName" => ^first_name,
                 "lastName" => ^last_name
               }
             } = json_response(conn, 200)
    end

    @tag :api_controller
    test "returns 404 if not found", %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      contact = insert!(:contact, project_id: other_project.id)
      conn = get(conn, Routes.api_path(conn, :show_contact, contact.id))

      assert %{"errors" => [%{"status" => "404", "title" => "Not found"}]} =
               json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/contacts/:id" do
    @tag :api_controller
    test "updates contact", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      params = %{"firstName" => "Updated Name"}
      conn = patch(conn, Routes.api_path(conn, :update_contact, contact.id, data: params))
      assert %{"data" => %{"firstName" => "Updated Name"}} = json_response(conn, 200)
    end

    @tag :api_controller
    test "renders changeset error", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      params = %{"email" => "__invalid__email"}
      conn = patch(conn, Routes.api_path(conn, :update_contact, contact.id, data: params))

      assert %{"errors" => errors} = json_response(conn, 400)

      assert Enum.find(errors, fn error ->
               match?(%{"pointer" => "/data/attributes/email"}, error)
             end)
    end

    @tag :api_controller
    test "returns 404 if not found", %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      contact = insert!(:contact, project_id: other_project.id)
      data = %{"email" => "__invalid__email"}
      conn = patch(conn, Routes.api_path(conn, :update_contact, contact.id, data: data))

      assert %{"errors" => [%{"status" => "404", "title" => "Not found"}]} =
               json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/contacts/:id" do
    @tag :api_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      conn = delete(conn, Routes.api_path(conn, :delete_contact, contact.id))
      assert conn.status == 204
      assert nil == Keila.Contacts.get_contact(contact.id)

      conn = delete(conn, Routes.api_path(conn, :delete_contact, contact.id))
      assert conn.status == 204
    end
  end

  defp put_token_header(conn, token) do
    conn |> put_req_header("authorization", "Bearer: #{token}")
  end
end
