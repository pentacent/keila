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

      response = html_response(conn, 200)
      assert response =~ "Unsubscribe"
    end
  end

  describe "HMAC-based unsubscribe routes" do
    @describetag :public_form_controller
    
    defp generate_test_hmac(project_id, recipient_id) do
      key = Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.fetch!(:secret_key_base)
      message = "unsubscribe:" <> project_id <> ":" <> recipient_id
      
      :crypto.mac(:hmac, :sha256, key, message)
      |> Base.url_encode64(padding: false)
    end
    
    test "GET /unsubscribe/:p_id/:r_id/:hmac shows unsubscribe page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id, status: :active)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      recipient = insert!(:mailings_recipient, campaign: campaign, contact: contact)
      
      # Create a valid HMAC for testing
      hmac = generate_test_hmac(project.id, recipient.id)
      
      conn = get(conn, Routes.public_form_path(conn, :unsubscribe, project.id, recipient.id, hmac))
      
      response = html_response(conn, 200)
      assert response =~ "Unsubscribe"
      assert response =~ "Are you sure you want to unsubscribe"
      assert response =~ "handleUnsubscribe()"
      
      # Contact should still be active (not auto-unsubscribed)
      assert %{status: :active} = Contacts.get_contact(contact.id)
    end
    
    test "POST /unsubscribe/:p_id/:r_id/:hmac processes unsubscribe", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id, status: :active)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      recipient = insert!(:mailings_recipient, campaign: campaign, contact: contact)
      
      # Create a valid HMAC for testing
      hmac = generate_test_hmac(project.id, recipient.id)
      
      conn = post(conn, Routes.public_form_path(conn, :unsubscribe, project.id, recipient.id, hmac), %{})
      
      response = html_response(conn, 200)
      assert response =~ "You have been unsubscribed"
      
      # Check that recipient was unsubscribed
      updated_recipient = Keila.Repo.get(Keila.Mailings.Recipient, recipient.id)
      assert not is_nil(updated_recipient.unsubscribed_at)
    end
    
    test "GET /unsubscribe/:p_id/:r_id/:hmac rejects invalid HMAC", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id, status: :active)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      recipient = insert!(:mailings_recipient, campaign: campaign, contact: contact)
      
      # Use invalid HMAC
      invalid_hmac = "invalid_hmac_string"
      
      conn = get(conn, Routes.public_form_path(conn, :unsubscribe, project.id, recipient.id, invalid_hmac))
      
      assert conn.status == 404
      assert %{status: :active} = Contacts.get_contact(contact.id)
    end

    test "POST /unsubscribe/:p_id/:r_id/:hmac supports List-Unsubscribe-Post", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      contact = insert!(:contact, project_id: project.id, status: :active)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      recipient = insert!(:mailings_recipient, campaign: campaign, contact: contact)
      
      # Create a valid HMAC for testing
      hmac = generate_test_hmac(project.id, recipient.id)
      
      # Test with List-Unsubscribe=One-Click parameter (used by email clients)
      conn = post(conn, Routes.public_form_path(conn, :unsubscribe, project.id, recipient.id, hmac), 
                  %{"List-Unsubscribe" => "One-Click"})
      
      response = html_response(conn, 200)
      assert response =~ "You have been unsubscribed"
      
      # Check that recipient was unsubscribed
      updated_recipient = Keila.Repo.get(Keila.Mailings.Recipient, recipient.id)
      assert not is_nil(updated_recipient.unsubscribed_at)
    end
  end
end
