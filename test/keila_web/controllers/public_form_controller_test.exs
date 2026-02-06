defmodule KeilaWeb.PublicFormControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Contacts
  alias Keila.Mailings
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

    test "updates existing contact and marks them as active", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      existing_contact = insert!(:contact, project_id: project.id, status: :unreachable)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false},
          field_settings: [
            %{field: :email, cast: true},
            %{field: :first_name, cast: true}
          ]
        )

      params = params(:contact, project_id: project.id, email: existing_contact.email)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)
      assert html_response(conn, 200) =~ ~r{Thank you}
      assert [contact] = Contacts.get_project_contacts(project.id)
      assert contact.id == existing_contact.id
      assert contact.status == :active
      assert contact.first_name == params["first_name"]
      assert contact.last_name == existing_contact.last_name
    end

    test "ignores submissions with honeypot field", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      params = params(:contact, project_id: project.id)

      conn =
        post(conn, Routes.public_form_path(conn, :show, form.id),
          contact: params,
          h: %{foo: "bar"}
        )

      assert html_response(conn, 200) =~ ~r{Thank you}
      assert [] == Contacts.get_project_contacts(project.id)
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

  describe "Deprecated: GET /unsubscribe/:p_id/:c_id" do
    @describetag :public_form_controller

    test "always shows delay message", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      conn = get(conn, Routes.public_form_path(conn, :unsubscribe, project.id, contact.id))
      assert html_response(conn, 200) =~ "Unsubscribing ..."
    end
  end

  describe "Deprecated: POST /unsubscribe/:p_id/:c_id" do
    @describetag :public_form_controller
    test "unsubscribes contact", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      conn = post(conn, Routes.public_form_path(conn, :unsubscribe, project.id, contact.id))
      assert html_response(conn, 200) =~ "You have been unsubscribed"
      assert %{status: :unsubscribed} = Contacts.get_contact(contact.id)
    end

    test "shows no error for non-existent contacts", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      conn =
        post(
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

  describe "GET /unsubscribe/:project_id/:recipient_id/:hmac" do
    @describetag :public_form_controller
    test "shows confirmation page when recipient sent_at is recent", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      recipient =
        insert!(:mailings_recipient, campaign: campaign, contact: contact, sent_at: now())

      unsubscribe_link = Mailings.get_unsubscribe_link(project.id, recipient.id)
      conn = get(conn, unsubscribe_link)

      assert html_response(conn, 200) =~ "Unsubscribing ..."
      assert %{status: :active} = Contacts.get_contact(contact.id)
    end

    test "unsubscribes immediately when sent_at is not recent", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      recipient =
        insert!(:mailings_recipient,
          campaign: campaign,
          contact: contact,
          sent_at: ten_minutes_ago()
        )

      unsubscribe_link = Mailings.get_unsubscribe_link(project.id, recipient.id)
      conn = get(conn, unsubscribe_link)

      assert html_response(conn, 200) =~ "You have been unsubscribed"
      assert %{status: :unsubscribed} = Contacts.get_contact(contact.id)
    end
  end

  describe "POST /unsubscribe/:project_id/:recipient_id/:hmac" do
    @describetag :public_form_controller
    test "unsubscribes contact via POST", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      recipient =
        insert!(:mailings_recipient, campaign: campaign, contact: contact, sent_at: now())

      unsubscribe_link = Mailings.get_unsubscribe_link(project.id, recipient.id)
      conn = post(conn, unsubscribe_link, hmac: "ignored")

      assert html_response(conn, 200) =~ "You have been unsubscribed"
      assert %{status: :unsubscribed} = Contacts.get_contact(contact.id)
    end
  end

  defp now() do
    DateTime.utc_now(:second)
  end

  defp ten_minutes_ago() do
    DateTime.utc_now(:second) |> DateTime.add(-600, :second)
  end
end
