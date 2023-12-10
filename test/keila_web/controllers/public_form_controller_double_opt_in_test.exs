defmodule KeilaWeb.PublicFormControllerDoubleOptInTest do
  use KeilaWeb.ConnCase, async: false
  use Oban.Testing, repo: Keila.Repo
  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Repo
  @endpoint KeilaWeb.Endpoint

  @tag :double_opt_in
  describe "POST /forms/:id" do
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
  end

  @tag :double_opt_in
  describe "GET /double-opt-in" do
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

      assert [%Contact{email: ^email}] = Contacts.get_project_contacts(project.id)
    end
  end

  @tag :double_opt_in
  describe "GET /double-opt-in/cancel" do
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
