defmodule KeilaWeb.ApiSegmentControllerTest do
  use KeilaWeb.ApiCase

  describe "GET /api/v1/segments" do
    @tag :api_segment_controller
    test "lists segments", %{authorized_conn: conn, project: project} do
      n = 10
      insert_n!(:contacts_segment, n, fn _n -> %{project_id: project.id} end)

      conn = get(conn, Routes.api_segment_path(conn, :index))

      assert %{"data" => segments} = json_response(conn, 200)
      assert Enum.count(segments) == n
    end
  end

  describe "POST /api/v1/segments" do
    @tag :api_segment_controller
    test "creates new segments", %{authorized_conn: conn} do
      filter = %{
        "$or" => [%{"email" => %{"like" => "%.com"}}, %{"email" => %{"like" => "%.org"}}]
      }

      body = %{
        "data" => %{
          "name" => "Test Segment",
          "filter" => filter
        }
      }

      conn = post_json(conn, Routes.api_segment_path(conn, :create), body)

      assert %{
               "data" => %{
                 "name" => "Test Segment",
                 "filter" => ^filter
               }
             } = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/segments/:id" do
    @tag :api_segment_controller
    test "retrieves existing segment", %{authorized_conn: conn, project: project} do
      %{id: id, name: name, filter: filter} = insert!(:contacts_segment, project_id: project.id)

      conn = get(conn, Routes.api_segment_path(conn, :show, id))

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => ^name,
                 "filter" => ^filter
               }
             } = json_response(conn, 200)
    end
  end

  describe "PATCH /api/v1/segments/:id" do
    @tag :api_segment_controller
    test "updates existing segment", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:contacts_segment, project_id: project.id)

      body = %{"data" => %{"name" => "Updated Name", "filter" => %{"email" => "new@example.com"}}}
      conn = patch_json(conn, Routes.api_segment_path(conn, :update, id), body)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => "Updated Name",
                 "filter" => %{
                   "email" => "new@example.com"
                 }
               }
             } = json_response(conn, 200)

      assert %{name: "Updated Name"} = Keila.Contacts.get_segment(id)
    end
  end

  describe "DELETE /api/v1/segments/:id" do
    @tag :api_segment_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:contacts_segment, project_id: project.id)

      conn = delete(conn, Routes.api_segment_path(conn, :delete, id))

      assert nil == Keila.Contacts.get_segment(id)

      conn = delete(conn, Routes.api_segment_path(conn, :delete, id))
      assert conn.status == 204
    end
  end
end
