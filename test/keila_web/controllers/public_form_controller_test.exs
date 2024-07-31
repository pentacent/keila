defmodule KeilaWeb.PublicFormControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Contacts
  @endpoint KeilaWeb.Endpoint

  describe "GET /forms/:id" do
    @describetag :public_form_controller
    test "displays configured form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      {:ok, form} = Contacts.create_empty_form(project.id)

      conn = get(conn, Routes.public_form_path(conn, :show, form.id))
      assert html_response(conn, 200) =~ ~r{#{form.name}\s*</h1>}
    end
  end

  describe "POST /forms/:id" do
    @describetag :public_form_controller
    test "submits configured form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      params = params(:contact, project_id: project.id)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)
      assert html_response(conn, 200) =~ ~r{Thank you}
      assert [contact] = Contacts.get_project_contacts(project.id)
      assert contact.email == params["email"]
    end

    test "Requires Captcha and validates fields", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: true})
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: %{})
      assert html_response(conn, 400) =~ ~r{Please complete the captcha}
      assert html_response(conn, 400) =~ ~r{can&#39;t be blank}
      assert [] == Contacts.get_project_contacts(project.id)
    end

    test "redirects if settings.success_url is set", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, success_url: "https://example.com"}
        )

      params = params(:contact, project_id: project.id)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)
      assert redirected_to(conn, 302) == "https://example.com"
    end
  end

  describe "GET /unsubscribe/:p_id/:c_id" do
    @describetag :public_form_controller
    test "unsubscribes contact", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      conn = get(conn, Routes.public_form_path(conn, :unsubscribe, project.id, contact.id))
      assert html_response(conn, 200) =~ "You have been unsubscribed"
      assert %{status: :unsubscribed} = Contacts.get_contact(contact.id)
    end

    test "shows no error for non-existent contacts", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      conn =
        get(
          conn,
          Routes.public_form_path(
            conn,
            :unsubscribe,
            project.id,
            elem(Contacts.Contact.Id.cast(0), 1)
          )
        )

      assert html_response(conn, 200) =~ "You have been unsubscribed"
    end
  end
end
