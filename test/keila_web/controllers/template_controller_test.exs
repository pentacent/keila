defmodule KeilaWeb.TemplateControllerTest do
  use KeilaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Keila.Templates
  @endpoint KeilaWeb.Endpoint

  describe "GET /projects/:p_id/template" do
    @tag :template_controller
    test "list templates", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      templates = insert_n!(:template, 5, fn _ -> %{project_id: project.id} end)
      conn = get(conn, Routes.template_path(conn, :index, project.id))
      assert html_response = html_response(conn, 200)
      for template <- templates, do: assert(html_response =~ template.name)
    end

    @tag :template_controller
    test "show empty state", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.template_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first template"
    end
  end

  describe "GET /projects/:p_id/template/new" do
    @tag :template_controller
    test "shows creation page with name form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.template_path(conn, :new, project.id))
      assert html_response(conn, 200) =~ ~r{New Template\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/templates/new" do
    @tag :template_controller
    test "creates new template and redirects", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      params = %{"name" => "My Template"}
      conn = post(conn, Routes.template_path(conn, :post_new, project.id, template: params))
      assert redirected_to(conn, 302) =~ Routes.template_path(conn, :edit, project.id, "ntpl_")
    end

    @tag :template_controller
    test "validates params", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      params = %{"name" => ""}
      conn = post(conn, Routes.template_path(conn, :post_new, project.id, template: params))
      assert html_response(conn, 400) =~ ~r{can&#39;t be blank}
    end
  end

  describe "LV /projects/:p_id/templates/:id" do
    @tag :template_controller
    test "shows edit form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)
      conn = get(conn, Routes.template_path(conn, :edit, project.id, template.id))

      assert html_response(conn, 200) =~ ~r{Edit Template\s*</h1>}
    end

    @tag :template_controller
    test "generates template preview", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      template = insert!(:template, project_id: project.id, styles: "h1 { color: #ff00ff }")

      conn = get(conn, Routes.template_path(conn, :edit, project.id, template.id))
      {:ok, lv, html} = live(conn)

      assert html =~ "#ff00ff"

      assert lv
             |> element("#template")
             |> render_change(%{
               "template" => %{
                 "assigns" => %{
                   "signature" => "Signature with {{ invalid_assign | default: \"Liquid\"}}"
                 }
               }
             }) =~
               "Signature with Liquid"
    end
  end

  describe "PUT /projects/:p_id/templates/:id" do
    @tag :template_controller
    test "updates campaign and redirects to index", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)

      params = %{"name" => "New Name"}

      conn =
        put(conn, Routes.template_path(conn, :edit, project.id, template.id, template: params))

      assert redirected_to(conn, 302) == Routes.template_path(conn, :index, project.id)
      assert %{name: "New Name"} = Templates.get_template(template.id)
    end
  end

  describe "DELETE /templates/" do
    @tag :template_controller
    test "deletes template", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)

      path = Routes.template_path(conn, :delete, project.id)
      conn = delete(conn, path, template: %{"id" => [template.id]})

      assert redirected_to(conn, 302) == Routes.template_path(conn, :index, project.id)
      assert nil == Templates.get_template(template.id)
    end

    @tag :template_controller
    test "shows confirmation page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)

      path = Routes.template_path(conn, :delete, project.id)

      conn =
        delete(conn, path, template: %{"id" => [template.id], "require_confirmation" => "true"})

      refute nil == Templates.get_template(template.id)
      assert html_response(conn, 200) =~ ~r{Delete Templates\?\s*</h1>}
    end
  end

  describe "GET /projects/:p_id/templates/:id/clone" do
    @tag :template_controller
    test "shows form for cloning", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)
      conn = get(conn, Routes.template_path(conn, :clone, project.id, template.id))
      assert html_response(conn, 200) =~ ~r{Clone Template\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/templates/:id/clone" do
    @tag :template_controller
    test "clones template and redirects to edit page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)
      params = %{"name" => "New Title"}

      conn =
        post(conn, Routes.template_path(conn, :clone, project.id, template.id, template: params))

      assert redirected_to(conn, 302) =~ Routes.template_path(conn, :edit, project.id, "ntpl_")

      assert 2 == Templates.get_project_templates(project.id) |> Enum.count()
    end
  end
end
