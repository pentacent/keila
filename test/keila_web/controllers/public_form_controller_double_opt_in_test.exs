defmodule KeilaWeb.PublicFormControllerDoubleOptInTest do
  use KeilaWeb.ConnCase, async: false
  use Oban.Testing, repo: Keila.Repo
  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Repo
  @endpoint KeilaWeb.Endpoint

  describe "POST /forms/:id" do
    @describetag :double_opt_in
    test "submits form with double opt-in and sends opt-in email", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      params = params(:contact) |> Map.delete(:project_id)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)
      assert html_response(conn, 200) =~ ~r{Please confirm your email}
      assert [] = Contacts.get_project_contacts(project.id)
      assert form_params = Repo.one(Contacts.FormParams)
      assert form_params.params["email"] == params["email"]

      assert_enqueued(
        worker: Keila.Mailings.SendDoubleOptInMailWorker,
        args: %{"form_params_id" => form_params.id}
      )
    end

    test "DOI is also required for existing contacts", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      contact = insert!(:contact, project_id: project.id, email: "existing@example.com")

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      params = params(:contact, email: contact.email)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)

      assert html_response(conn, 200) =~ ~r{Please confirm your email}
      assert contact == Contacts.get_contact(contact.id)
      assert form_params = Repo.one(Contacts.FormParams)
      assert form_params.params["email"] == contact.email

      assert_enqueued(
        worker: Keila.Mailings.SendDoubleOptInMailWorker,
        args: %{"form_params_id" => form_params.id}
      )
    end

    test "redirects to double_opt_in_url if set", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{
            captcha_required: false,
            double_opt_in_required: true,
            double_opt_in_url: "https://example.com"
          }
        )

      params = params(:contact) |> Map.delete(:project_id)
      conn = post(conn, Routes.public_form_path(conn, :show, form.id), contact: params)
      assert redirected_to(conn, 302) == form.settings.double_opt_in_url
    end
  end

  describe "GET /double-opt-in" do
    @describetag :double_opt_in
    test "creates Contact from FormParams", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      email = "test@example.com"
      {:ok, form_params} = Contacts.create_form_params(form.id, %{email: email})
      hmac = Contacts.double_opt_in_hmac(form.id, form_params.id)

      conn =
        get(conn, Routes.public_form_path(conn, :double_opt_in, form.id, form_params.id, hmac))

      assert html_response(conn, 200)

      assert [contact = %Contact{email: ^email}] = Contacts.get_project_contacts(project.id)
      assert contact.double_opt_in_at
    end

    test "also works with custom data fields", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true},
          field_settings: [
            %{field: :email, cast: true, required: true},
            %{
              field: :data,
              key: "custom",
              cast: true,
              required: true,
              type: :enum,
              allowed_values: [%{label: "Foo", value: "foo"}]
            }
          ]
        )

      email = "test@example.com"
      custom = "foo"

      {:ok, form_params} =
        Contacts.create_form_params(form.id, %{email: email, data: %{"custom" => custom}})

      hmac = Contacts.double_opt_in_hmac(form.id, form_params.id)

      conn =
        get(conn, Routes.public_form_path(conn, :double_opt_in, form.id, form_params.id, hmac))

      assert html_response(conn, 200)

      assert [contact = %Contact{email: ^email, data: %{"custom" => ^custom}}] =
               Contacts.get_project_contacts(project.id)

      assert contact.double_opt_in_at
    end

    test "success_url supports Liquid", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{
            captcha_required: false,
            double_opt_in_required: true,
            success_url: "https://example.com/{{ contact.id }}"
          }
        )

      {:ok, form_params} = Contacts.create_form_params(form.id, %{email: "test@example.com"})
      hmac = Contacts.double_opt_in_hmac(form.id, form_params.id)

      conn =
        get(conn, Routes.public_form_path(conn, :double_opt_in, form.id, form_params.id, hmac))

      contact = Repo.one(Contact)
      assert redirected_to(conn, 302) == "https://example.com/#{contact.id}"
    end

    test "redirects to verbatim success_url if Liquid is invalid", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{
            captcha_required: false,
            double_opt_in_required: true,
            success_url: "https://example.com/{{{ invalid_liquid }}"
          }
        )

      {:ok, form_params} = Contacts.create_form_params(form.id, %{email: "test@example.com"})
      hmac = Contacts.double_opt_in_hmac(form.id, form_params.id)

      conn =
        get(conn, Routes.public_form_path(conn, :double_opt_in, form.id, form_params.id, hmac))

      assert redirected_to(conn, 302) == form.settings.success_url
    end
  end

  describe "GET /double-opt-in/cancel" do
    @describetag :double_opt_in
    test "deletes FormParams", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      email = "test@example.com"
      {:ok, form_params} = Contacts.create_form_params(form.id, %{email: email})
      hmac = Contacts.double_opt_in_hmac(form.id, form_params.id)

      conn =
        get(
          conn,
          Routes.public_form_path(conn, :cancel_double_opt_in, form.id, form_params.id, hmac)
        )

      assert html_response(conn, 200) =~ "You will not be subscribed to this list."

      assert [] = Contacts.get_project_contacts(project.id)
      assert nil == Repo.reload(form_params)
    end
  end
end
