defmodule KeilaWeb.ApiContactControllerTest do
  use KeilaWeb.ApiCase

  describe "API is authenticated with Bearer token" do
    @tag :api_contact_controller
    test "requires auth", %{conn: conn, token: token} do
      conn = get(conn, Routes.api_contact_path(conn, :index))

      assert %{"errors" => [%{"status" => "403", "title" => "Not authorized"}]} =
               json_response(conn, 403)

      conn =
        recycle(conn)
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(Routes.api_contact_path(conn, :index))

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/contacts" do
    @tag :api_contact_controller
    test "list contacts", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)

      conn = get(conn, Routes.api_contact_path(conn, :index))
      assert %{"data" => [contact_json]} = json_response(conn, 200)

      assert contact_json["id"] == contact.id
      assert contact_json["first_name"] == contact.first_name
      assert contact_json["last_name"] == contact.last_name
      assert contact_json["status"] |> String.to_atom() == contact.status
      assert contact_json["data"] == contact.data
      assert contact_json["inserted_at"] |> from_iso8601!() == contact.inserted_at
      assert contact_json["updated_at"] |> from_iso8601!() == contact.updated_at
    end

    defp from_iso8601!(string) do
      {:ok, date, _} = DateTime.from_iso8601(string)
      date
    end

    @tag :api_contact_controller
    test "uses pagination", %{authorized_conn: conn, project: project} do
      insert_n!(:contact, 50, fn _n -> %{project_id: project.id} end)

      page_size = :rand.uniform(25)
      page_count = ceil(50 / page_size)
      page = :rand.uniform(page_count)

      query = %{"paginate" => %{"page" => page, "page_size" => page_size}}
      conn = get(conn, Routes.api_contact_path(conn, :index, query))

      assert %{
               "meta" => %{
                 "page" => ^page,
                 "page_count" => ^page_count,
                 "count" => 50
               },
               "data" => _contacts
             } = json_response(conn, 200)
    end

    @tag :api_contact_controller
    test "supports filtering", %{authorized_conn: conn, project: project} do
      insert_n!(:contact, 50, fn n ->
        %{project_id: project.id, data: %{"even" => rem(n, 2) == 0}}
      end)

      query = %{"filter" => Jason.encode!(%{"data.even" => "true"})}
      conn = get(conn, Routes.api_contact_path(conn, :index, query))

      assert %{
               "meta" => %{
                 "count" => 25
               },
               "data" => [%{"data" => %{"even" => true}} | _]
             } = json_response(conn, 200)
    end

    @tag :api_contact_controller
    test "invalid filters create error", %{authorized_conn: conn} do
      query = %{"filter" => "___invalid-filter___"}
      conn = get(conn, Routes.api_contact_path(conn, :index, query))

      assert %{
               "errors" => [%{"parameter" => "filter"}]
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/contacts" do
    @tag :api_contact_controller
    test "creates contact", %{authorized_conn: conn} do
      body = %{
        "data" => %{"email" => "api@example.com", "first_name" => "Jane", "last_name" => "API"}
      }

      conn = post_json(conn, Routes.api_contact_path(conn, :create), body)

      assert %{
               "data" => %{
                 "email" => "api@example.com",
                 "first_name" => "Jane",
                 "last_name" => "API"
               }
             } = json_response(conn, 200)
    end

    @tag :api_contact_controller
    test "rejects params not in schema", %{authorized_conn: conn} do
      body = %{"data" => %{"__invalid_param__" => "value"}}
      conn = post_json(conn, Routes.api_contact_path(conn, :create), body)

      assert %{"errors" => errors} = json_response(conn, 400)

      assert Enum.find(errors, fn error ->
               match?(
                 %{"title" => "Unexpected field", "pointer" => "/data/__invalid_param__"},
                 error
               )
             end)
    end

    @tag :api_contact_controller
    test "renders changeset error", %{authorized_conn: conn} do
      body = %{"data" => %{"email" => "__invalid__email"}}
      conn = post_json(conn, Routes.api_contact_path(conn, :create), body)

      assert %{"errors" => errors} = json_response(conn, 400)

      assert Enum.find(errors, fn error ->
               match?(%{"pointer" => "/data/attributes/email"}, error)
             end)
    end
  end

  describe "GET /api/v1/contacts/:id" do
    @tag :api_contact_controller
    test "retrieves contact", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      %{email: email, first_name: first_name, last_name: last_name} = contact

      conn = get(conn, Routes.api_contact_path(conn, :show, contact.id))

      assert %{
               "data" => %{
                 "email" => ^email,
                 "first_name" => ^first_name,
                 "last_name" => ^last_name
               }
             } = json_response(conn, 200)
    end

    @tag :api_contact_controller
    test "returns 404 if not found", %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      contact = insert!(:contact, project_id: other_project.id)
      conn = get(conn, Routes.api_contact_path(conn, :show, contact.id))

      assert %{"errors" => [%{"status" => "404", "title" => "Not found"}]} =
               json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/contacts/:id" do
    @tag :api_contact_controller
    test "updates contact", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      body = %{"data" => %{"first_name" => "Updated Name"}}
      conn = patch_json(conn, Routes.api_contact_path(conn, :update, contact.id), body)
      assert %{"data" => %{"first_name" => "Updated Name"}} = json_response(conn, 200)
    end

    test "contact can be updated from email and external id", %{
      authorized_conn: conn,
      project: project
    } do
      contact = insert!(:contact, project_id: project.id)

      body = %{"data" => %{"first_name" => "Updated Name"}}
      params = %{"id_type" => "email"}
      path = Routes.api_contact_path(conn, :update, contact.email, params)
      conn = patch_json(conn, path, body)
      assert %{"data" => %{"first_name" => "Updated Name"}} = json_response(conn, 200)

      body = %{"data" => %{"first_name" => "Updated Name 2"}}
      params = %{"id_type" => "external_id"}
      path = Routes.api_contact_path(conn, :update, contact.external_id, params)
      conn = patch_json(recycle(conn), path, body)
      assert %{"data" => %{"first_name" => "Updated Name 2"}} = json_response(conn, 200)
    end

    test "allows changing contact status", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      body = %{"data" => %{"status" => "unsubscribed"}}
      conn = patch_json(conn, Routes.api_contact_path(conn, :update, contact.id), body)
      assert %{"data" => %{"status" => "unsubscribed"}} = json_response(conn, 200)
    end

    @tag :api_contact_controller
    test "renders changeset error", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      body = %{"data" => %{"email" => "__invalid__email"}}
      conn = patch_json(conn, Routes.api_contact_path(conn, :update, contact.id), body)

      assert %{"errors" => errors} = json_response(conn, 400)

      assert Enum.find(errors, fn error ->
               match?(%{"pointer" => "/data/attributes/email"}, error)
             end)
    end

    @tag :api_contact_controller
    test "returns 404 if not found", %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      contact = insert!(:contact, project_id: other_project.id)
      body = %{"data" => %{"email" => "__invalid__email"}}
      conn = patch_json(conn, Routes.api_contact_path(conn, :update, contact.id), body)

      assert %{"errors" => [%{"status" => "404", "title" => "Not found"}]} =
               json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/contacts/:id/data" do
    @tag :api_contact_controller
    test "updates contact data", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id, data: %{"foo" => "bar"})
      body = %{"data" => %{"fizz" => "buzz"}}
      conn = patch_json(conn, Routes.api_contact_path(conn, :update_data, contact.id), body)
      assert %{"foo" => "bar", "fizz" => "buzz"} == json_response(conn, 200)["data"]["data"]
    end
  end

  describe "POST /api/v1/contacts/:id/data" do
    @tag :api_contact_controller
    test "replaces contact data", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id, data: %{"foo" => "bar"})
      body = %{"data" => %{"fizz" => "buzz"}}
      conn = post_json(conn, Routes.api_contact_path(conn, :update_data, contact.id), body)
      assert %{"fizz" => "buzz"} == json_response(conn, 200)["data"]["data"]
    end
  end

  describe "DELETE /api/v1/contacts/:id" do
    @tag :api_contact_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      conn = delete(conn, Routes.api_contact_path(conn, :delete, contact.id))
      assert conn.status == 204
      assert nil == Keila.Contacts.get_contact(contact.id)

      conn = delete(conn, Routes.api_contact_path(conn, :delete, contact.id))
      assert conn.status == 204
    end

    @tag :api_contact_controller
    test "supports id_type param", %{authorized_conn: conn, project: project} do
      contact = insert!(:contact, project_id: project.id)
      conn = delete(conn, Routes.api_contact_path(conn, :delete, contact.email, id_type: "email"))
      assert conn.status == 204
      assert nil == Keila.Contacts.get_contact(contact.id)

      conn = delete(conn, Routes.api_contact_path(conn, :delete, contact.id))
      assert conn.status == 204
    end
  end
end
