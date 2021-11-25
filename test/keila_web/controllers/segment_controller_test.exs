defmodule KeilaWeb.SegmentControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Contacts
  @endpoint KeilaWeb.Endpoint

  describe "GET /segments" do
    @tag :segment_controller
    test "has empty state", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.segment_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first segment"
    end

    @tag :segment_controller
    test "lists segments", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      segments = insert_n!(:contacts_segment, 5, fn _ -> %{project_id: project.id} end)
      conn = get(conn, Routes.segment_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ ~r{Segments\s*</h1>}

      for segment <- segments do
        assert html_response(conn, 200) =~ segment.name
      end
    end
  end

  describe "POST /segments" do
    @tag :segment_controller
    test "creates new form and redirects to edit page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      conn =
        post(
          conn,
          Routes.segment_path(conn, :create, project.id, %{"segment" => %{"name" => "My Segment"}})
        )

      assert redirected_to(conn, 302) =~ ~r{/projects/#{project.id}/segments/sgm_\w+}
    end
  end

  describe "LV /projects/:p_id/segments/:id" do
    @tag :segment_controller
    test "shows edit form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      segment = insert!(:contacts_segment, project_id: project.id)

      conn = get(conn, Routes.segment_path(conn, :edit, project.id, segment.id))
      assert html_response(conn, 200) =~ ~r{Edit Segment\s*</h1>}
    end
  end

  describe "DELETE /projects/:p_id/segments" do
    @tag :segment_controller
    test "deletes segment(s)", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      segment = insert!(:contacts_segment, project_id: project.id)

      conn =
        delete(
          conn,
          Routes.segment_path(conn, :delete, project.id, segment: %{"id" => [segment.id]})
        )

      assert redirected_to(conn, 302) == Routes.segment_path(conn, :index, project.id)
      assert nil == Contacts.get_segment(segment.id)
    end

    @tag :segment_controller
    test "shows confirmation page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      segment = insert!(:contacts_segment, project_id: project.id)

      conn =
        delete(
          conn,
          Routes.segment_path(conn, :delete, project.id,
            segment: %{"id" => [segment.id], "require_confirmation" => true}
          )
        )

      assert html_response(conn, 200) =~ ~r{Delete Segments\?\s*</h1>}
      assert segment == Contacts.get_segment(segment.id)
    end
  end
end
