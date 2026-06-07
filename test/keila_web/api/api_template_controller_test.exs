defmodule KeilaWeb.ApiTemplateControllerTest do
  use KeilaWeb.ApiCase

  describe "GET /api/v1/templates" do
    @tag :api_template_controller
    test "lists templates", %{authorized_conn: conn, project: project} do
      insert_n!(:template, 3, fn _n -> %{project_id: project.id} end)

      conn = get(conn, Routes.api_template_path(conn, :index))

      assert %{"data" => templates} = json_response(conn, 200)
      assert Enum.count(templates) == 3
    end
  end

  describe "POST /api/v1/templates" do
    @tag :api_template_controller
    test "creates a template and returns its declared slots",
         %{authorized_conn: conn, project: _project} do
      body = %{
        "data" => %{
          "name" => "Welcome Email",
          "type" => "mjml",
          "mjml_body" =>
            "<mjml><mj-body><keila-content name=\"main\"><mj-text>Welcome!</mj-text></keila-content></mj-body></mjml>"
        }
      }

      conn = post_json(conn, Routes.api_template_path(conn, :create), body)

      assert %{
               "data" => %{
                 "id" => _id,
                 "name" => "Welcome Email",
                 "type" => "mjml",
                 "mjml_content_slots" => [
                   %{"name" => "main", "default_content" => "<mj-text>\n  Welcome!\n</mj-text>\n"}
                 ]
               }
             } = json_response(conn, 200)
    end

    @tag :api_template_controller
    test "rejects creation without a type", %{authorized_conn: conn, project: _project} do
      body = %{"data" => %{"name" => "No Type"}}
      conn = post_json(conn, Routes.api_template_path(conn, :create), body)
      assert %{"errors" => _} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/templates/:id" do
    @tag :api_template_controller
    test "returns a hybrid template without any content slots property",
         %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:template, project_id: project.id, type: :hybrid)

      conn = get(conn, Routes.api_template_path(conn, :show, id))

      assert %{"data" => %{"id" => ^id, "type" => "hybrid"} = data} = json_response(conn, 200)
      refute Enum.any?(Map.keys(data), &String.ends_with?(&1, "_content_slots"))
    end
  end

  describe "PATCH /api/v1/templates/:id" do
    @tag :api_template_controller
    test "updates the name", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:template, project_id: project.id, type: :mjml)

      body = %{"data" => %{"name" => "Renamed"}}
      conn = patch_json(conn, Routes.api_template_path(conn, :update, id), body)

      assert %{"data" => %{"id" => ^id, "name" => "Renamed"}} = json_response(conn, 200)
    end

    @tag :api_template_controller
    test "rejects changing the type (immutable)", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:template, project_id: project.id, type: :mjml)

      body = %{"data" => %{"type" => "text"}}
      conn = patch_json(conn, Routes.api_template_path(conn, :update, id), body)

      assert %{"errors" => _} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/templates/:id" do
    @tag :api_template_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:template, project_id: project.id)

      conn = delete(conn, Routes.api_template_path(conn, :delete, id))
      assert conn.status == 204
    end
  end
end
