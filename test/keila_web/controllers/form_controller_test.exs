defmodule KeilaWeb.FormControllerTest do
  use KeilaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Keila.Contacts
  @endpoint KeilaWeb.Endpoint

  defp setup_conn_and_project(conn) do
    conn = with_login(conn)
    project = setup_project(conn)
    %{conn: conn, project: project}
  end

  describe "GET /forms/:id" do
    @tag :form_controller
    test "displays configured form", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      {:ok, form} = Contacts.create_empty_form(project.id)

      conn = get(conn, Routes.form_path(conn, :display, form.id))
      assert html_response(conn, 200) =~ ~r{#{form.name}\s*</h1>}
    end
  end

  describe "POST /forms/:id" do
    @tag :form_controller
    test "submits configured form", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      params = params(:contact, project_id: project.id)
      conn = post(conn, Routes.form_path(conn, :display, form.id), contact: params)
      assert html_response(conn, 200) =~ ~r{Thank you}
      assert [contact] = Contacts.get_project_contacts(project.id)
      assert contact.email == params["email"]
    end

    @tag :form_controller
    test "Requires Captcha and validates fields", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: true})
      conn = post(conn, Routes.form_path(conn, :display, form.id), contact: %{})
      assert html_response(conn, 400) =~ ~r{Please complete the captcha}
      assert html_response(conn, 400) =~ ~r{can&#39;t be blank}
      assert [] == Contacts.get_project_contacts(project.id)
    end
  end

  describe "GET /unsubscribe/:p_id/:c_id" do
    @tag :form_controller
    test "removes contact", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      conn = get(conn, Routes.form_path(conn, :unsubscribe, project.id, contact.id))
      assert html_response(conn, 200) =~ "You have been unsubscribed"
      assert nil == Contacts.get_contact(contact.id)
    end

    @tag :form_controller
    test "shows no error for non-existent contacts", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      conn = get(conn, Routes.form_path(conn, :unsubscribe, project.id, elem(Contacts.Contact.Id.cast(0), 1)))
      assert html_response(conn, 200) =~ "You have been unsubscribed"
    end
  end

  describe "GET /projects/:p_id/forms" do
    @tag :form_controller
    test "has empty state", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      conn = get(conn, Routes.form_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first form"
    end

    @tag :form_controller
    test "lists forms", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
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
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      conn = get(conn, Routes.form_path(conn, :new, project.id))
      assert redirected_to(conn, 302) =~ ~r{/projects/#{project.id}/forms/frm_\w+}
    end
  end

  describe "LV /projects/:p_id/forms/:id" do
    @tag :form_controller
    test "shows edit form", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})

      conn = get(conn, Routes.form_path(conn, :edit, project.id, form.id))
      assert html_response(conn, 200) =~ ~r{Edit Form\s*</h1>}
    end

    @tag :form_controller
    test "updates form preview on change", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
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
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})

      params = %{"settings" => %{"id" => form.settings.id, "captcha_required" => true}}
      put(conn, Routes.form_path(conn, :post_edit, project.id, form.id, form: params))
      assert %{settings: %{captcha_required: true}} = Contacts.get_form(form.id)
    end
  end

  describe "DELETE /projects/:p_id/forms" do
    @tag :form_controller
    test "deletes form(s)", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id)
      conn = delete(conn, Routes.form_path(conn, :delete, project.id, form: %{"id" => [form.id]}))
      assert redirected_to(conn, 302) == Routes.form_path(conn, :index, project.id)
      assert nil == Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "shows confirmation page", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
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
