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

    @tag :form_controller
    test "adds and removes custom fields", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      assert lv
             |> element("#form")
             |> render_change(%{"form" => %{"field_settings_sort" => ["0", "new"]}}) =~
               "custom_field_1"

      refute lv
             |> element("#form")
             |> render_change(%{"form" => %{"field_settings_drop" => ["1"]}}) =~
               "custom_field_1"
    end

    @tag :form_controller
    test "numbers the data keys of new custom fields", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false},
          field_settings: [
            %Keila.Contacts.Form.FieldSettings{field: :email, cast: true, required: true},
            %Keila.Contacts.Form.FieldSettings{
              field: :data,
              key: "custom_field_3",
              label: "Pet",
              type: :string
            },
            %Keila.Contacts.Form.FieldSettings{
              field: :data,
              key: "custom_field_x",
              label: "Dog",
              type: :string
            }
          ]
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      assert lv
             |> element("#form")
             |> render_change(%{"form" => %{"field_settings_sort" => ["0", "1", "2", "new"]}}) =~
               ~s(value="custom_field_4")

      html =
        lv
        |> element("#form")
        |> render_change(%{"form" => %{"field_settings_sort" => ["0", "1", "2", "3", "new"]}})

      assert html =~ ~s(value="custom_field_4")
      assert html =~ ~s(value="custom_field_5")
    end

    @tag :form_controller
    test "adds and removes options of unsaved custom fields", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})
      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("#form")
      |> render_change(%{"form" => %{"field_settings_sort" => ["0", "new"]}})

      lv
      |> element("#form")
      |> render_change(%{"form" => %{"field_settings" => %{"1" => %{"type" => "enum"}}}})

      assert lv
             |> element("#form")
             |> render_change(%{
               "form" => %{"field_settings" => %{"1" => %{"allowed_values_sort" => ["new"]}}}
             }) =~ "option-1"

      refute lv
             |> element("#form")
             |> render_change(%{
               "form" => %{"field_settings" => %{"1" => %{"allowed_values_drop" => ["0"]}}}
             }) =~ "option-1"
    end
  end

  describe "LV /projects/:p_id/forms/:id email dialog" do
    @tag :form_controller
    test "edits the welcome email in a dialog and saves it with the form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      refute has_element?(lv, "#welcome_email-dialog")

      html =
        lv
        |> element("button[phx-target='#welcome_email'][phx-click=open]")
        |> render_click()

      assert html =~ "welcome_email-form"
      assert html =~ Keila.Mailings.WelcomeMessage.default_subject()

      lv
      |> element("#welcome_email-form")
      |> render_change(%{"email" => %{"subject" => "Custom welcome", "text_body" => "Hi there"}})

      lv |> element("#welcome_email-form") |> render_submit(%{"email" => %{}})
      refute has_element?(lv, "#welcome_email-dialog")

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{
               welcome_email: %Keila.Mailings.Email{
                 subject: "Custom welcome",
                 text_body: "Hi there"
               }
             } = Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "opens on the content view when a subject or template is set", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Lois"),
          double_opt_in_email: build(:mailings_email, subject: nil, template_id: template.id),
          settings: %{
            captcha_required: false,
            welcome_enabled: true,
            double_opt_in_required: true
          }
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      assert has_element?(lv, "#welcome_email-editor")

      lv |> element("#welcome_email-form") |> render_submit(%{"email" => %{}})

      html =
        lv
        |> element("button[phx-target='#double_opt_in_email'][phx-click=open]")
        |> render_click()

      assert has_element?(lv, "#double_opt_in_email-editor")
      assert html =~ "so that contacts can confirm their subscription"
    end

    @tag :form_controller
    test "previews the default content of an empty email", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#double_opt_in_email'][phx-click=open]")
      |> render_click()

      html = lv |> element("button[phx-click=show_content]") |> render_click()

      assert html =~ "Please click here to confirm your subscription"
    end

    @tag :form_controller
    test "welcome preview reflects the pending email", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv |> element("a[phx-value-tab=welcome-email]") |> render_click()

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{
        "email" => %{"subject" => "Pending subject", "text_body" => "Pending body"}
      })

      refute has_element?(lv, "#welcome_email-dialog")
      assert render(lv) =~ "Pending body"
    end

    @tag :form_controller
    test "creates a new email without the rich text editor until enabled", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: nil,
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"subject" => "Welcome, Meg"}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{subject: "Welcome, Meg", editor_config: %{enable_wysiwyg: false}}} =
               Contacts.get_form(form.id)

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("button[phx-click=show_settings]") |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"editor_config" => %{"enable_wysiwyg" => "true"}}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{editor_config: %{enable_wysiwyg: true}}} =
               Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "creates a new email without changing the settings", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: nil,
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("button[phx-click=show_content]") |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"text_body" => "Hi, Meg"}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{
               welcome_email: %{
                 type: :markdown,
                 text_body: "Hi, Meg",
                 editor_config: %{enable_wysiwyg: false}
               }
             } = Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "shows the rich text option for emails without editor config", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      # Emails created via the API have no editor config
      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, editor_config: nil),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("button[phx-click=show_settings]") |> render_click()

      assert has_element?(
               lv,
               "#welcome_email-form input[type=checkbox][name='email[editor_config][enable_wysiwyg]'][checked]"
             )
    end

    @tag :form_controller
    test "merges changes from multiple dialog sessions", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Lois", text_body: "Hi, Lois"),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      for email_params <- [
            %{"subject" => "Welcome, Stewie"},
            %{"text_body" => "Hi, Stewie"},
            %{"subject" => "Welcome, Lois"}
          ] do
        lv
        |> element("button[phx-target='#welcome_email'][phx-click=open]")
        |> render_click()

        lv |> element("#welcome_email-form") |> render_submit(%{"email" => email_params})
      end

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{subject: "Welcome, Lois", text_body: "Hi, Stewie"}} =
               Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "keeps changes when switching tabs", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Lois", text_body: "Hi, Lois"),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_change(%{"email" => %{"text_body" => "Hi, Stewie"}})

      lv |> element("button[phx-click=show_settings]") |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"subject" => "Welcome, Stewie"}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{subject: "Welcome, Stewie", text_body: "Hi, Stewie"}} =
               Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "changing the email type removes incompatible template", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      template = insert!(:template, project_id: project.id, type: :hybrid)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email:
            build(:mailings_email, subject: "Welcome, Lois", template_id: template.id),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("button[phx-click=show_settings]") |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_change(%{"email" => %{"type" => "text", "template_id" => template.id}})

      lv |> element("button[phx-click=show_content]") |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"text_body" => "Hi, Lois"}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{type: :text, template_id: nil}} = Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "cancelling the dialog discards its changes", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Lois", text_body: "Hi, Lois"),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_change(%{"email" => %{"text_body" => "Hi, Stewie"}})

      lv |> element("button[phx-click=cancel]") |> render_click()
      refute has_element?(lv, "#welcome_email-dialog")

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{text_body: "Hi, Lois"}} = Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "keeps the dialog open when the email is invalid", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      html =
        lv
        |> element("#welcome_email-form")
        |> render_submit(%{"email" => %{"type" => "html"}})

      assert has_element?(lv, "#welcome_email-dialog")
      assert html =~ "can&#39;t be blank when no template is set"
    end

    @tag :form_controller
    test "keeps unsaved custom fields when changing emails", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Lois"),
          settings: %{
            captcha_required: false,
            welcome_enabled: true,
            double_opt_in_required: true
          }
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("#form")
      |> render_change(%{"form" => %{"field_settings_sort" => ["0", "new"]}})

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("#welcome_email-form") |> render_submit(%{"email" => %{}})

      lv
      |> element("button[phx-value-email=double_opt_in_email][phx-click=reset_email]")
      |> render_click()

      assert render(lv) =~ "custom_field_1"
    end

    @tag :form_controller
    test "merges the template from the email editor", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      template =
        insert!(:template,
          project_id: project.id,
          type: :text,
          text_body: ~s(Hi, <keila-content name="name">Brian</keila-content>)
        )

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email:
            build(:mailings_email,
              type: :text,
              subject: "Welcome, Brian",
              text_body: nil,
              template_id: template.id
            ),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv |> element("button[phx-click=merge_text_template]") |> render_click()
      # Waits for the update from the editor
      render(lv)

      lv |> element("#welcome_email-form") |> render_submit(%{"email" => %{}})
      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{text_body: "Hi, Brian", text_content: %{}}} =
               Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "reset replaces the email with default content on save", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Old"),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-value-email=welcome_email][phx-click=reset_email]")
      |> render_click()

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{welcome_email: %{subject: nil, text_body: nil}} = Contacts.get_form(form.id)
    end

    @tag :form_controller
    test "edits a reset email", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Old", text_body: "Old body"),
          settings: %{captcha_required: false, welcome_enabled: true}
        )

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("button[phx-value-email=welcome_email][phx-click=reset_email]")
      |> render_click()

      lv
      |> element("button[phx-target='#welcome_email'][phx-click=open]")
      |> render_click()

      lv
      |> element("#welcome_email-form")
      |> render_submit(%{"email" => %{"subject" => "Welcome, Peter"}})

      lv |> element("#form") |> render_submit()
      assert_redirect(lv, Routes.form_path(conn, :index, project.id))

      assert %{
               welcome_email: %{
                 subject: "Welcome, Peter",
                 text_body: nil,
                 editor_config: %{enable_wysiwyg: false}
               }
             } = Contacts.get_form(form.id)
    end
  end

  describe "LV /projects/:p_id/forms/:id save" do
    @tag :form_controller
    test "updates form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      form = insert!(:contacts_form, project_id: project.id, settings: %{captcha_required: false})

      {:ok, lv, _} = live(conn, Routes.form_path(conn, :edit, project.id, form.id))

      lv
      |> element("#form")
      |> render_submit(%{"form" => %{"settings" => %{"captcha_required" => "true"}}})

      assert_redirect(lv, Routes.form_path(conn, :index, project.id))
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
