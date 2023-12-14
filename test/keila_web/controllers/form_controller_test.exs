defmodule KeilaWeb.FormControllerTest do
  use KeilaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Keila.Contacts
  @endpoint KeilaWeb.Endpoint

  describe "GET /projects/:p_id/forms" do
    @tag :form_controller
    test "has empty state", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.form_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first form"
    end

    @tag :form_controller
    test "lists forms", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      forms = insert_n!(:contacts_form, 5, fn _ -> %{project_id: project.id} end)
      conn = get(conn, Routes.form_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ ~r{Forms\s*</h1>}

      for form <- forms do
        assert html_response(conn, 200) =~ form.name
      end
    end
  end

  describe "GET /projects/:p_id/forms/new" do
    @tag :form_controller
    test "creates new form and redirects to edit page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.form_path(conn, :new, project.id))
      assert redirected_to(conn, 302) =~ ~r{/projects/#{project.id}/forms/nfrm_\w+}
    end
  end

  describe "LV /projects/:p_id/forms/:id" do
    @tag :form_controller
    test "shows edit form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})

      conn = get(conn, Routes.form_path(conn, :edit, project.id, form.id))
      assert html_response(conn, 200) =~ ~r{Edit Form\s*</h1>}
    end

    @tag :form_controller
    test "updates form preview on change", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      refute render(lv) =~ "I am human."

      assert lv
             |> element("#form")
             |> render_change(%{"form" => %{"settings" => %{"captcha_required" => true}}}) =~
               ~r{I am human.}
    end
  end

  describe "PUT /projects/:p_id/forms/:id" do
    @tag :form_controller
    test "updates form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})

      params = %{"settings" => %{"id" => form.settings.id, "captcha_required" => true}}
      put(conn, Routes.form_path(conn, :post_edit, project.id, form.id, form: params))
      assert %{settings: %{captcha_required: true}} = Contacts.get_form(form.id)
    end
  end

  describe "DELETE /projects/:p_id/forms" do
    @tag :form_controller
    test "deletes form(s)", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id)
      conn = delete(conn, Routes.form_path(conn, :delete, project.id, form: %{"id" => [form.id]}))
      assert redirected_to(conn, 302) == Routes.form_path(conn, :index, project.id)
      assert nil == Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "shows confirmation page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id)

      conn =
        delete(
          conn,
          Routes.form_path(conn, :delete, project.id,
            form: %{"id" => [form.id], "require_confirmation" => true}
          )
        )

      assert html_response(conn, 200) =~ ~r{Delete Forms\?\s*</h1>}
      assert form == Contacts.get_form(form.id)
    end
  end
end
