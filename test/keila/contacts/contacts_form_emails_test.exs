defmodule Keila.Contacts.FormEmailsTest do
  use Keila.DataCase, async: true
  alias Keila.Contacts
  alias Keila.Mailings.Email

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "Form Emails Test"})

    %{project: project, user: user}
  end

  describe "form emails" do
    @describetag :contacts_form

    test "creating a form with email params embeds the email", %{project: project} do
      assert {:ok, form} =
               Contacts.create_form(project.id, %{
                 "name" => "Form",
                 "field_settings" => [%{"field" => "email", "required" => true}],
                 "welcome_email" => %{
                   "type" => "markdown",
                   "subject" => "Welcome",
                   "text_body" => "Hello!"
                 }
               })

      assert %Email{subject: "Welcome", type: :markdown} = form.welcome_email
      assert %Email{subject: "Welcome"} = Contacts.get_form(form.id).welcome_email
      assert is_nil(form.double_opt_in_email)
    end

    test "params update the email in place", %{project: project} do
      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Old", text_body: "Body")
        )

      assert {:ok, form} =
               Contacts.update_form(form.id, %{"welcome_email" => %{"subject" => "New"}})

      assert %Email{subject: "New", text_body: "Body"} = form.welcome_email
    end

    test "nil removes the email", %{project: project} do
      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email),
          double_opt_in_email: build(:mailings_email)
        )

      assert {:ok, form} = Contacts.update_form(form.id, %{"welcome_email" => nil})

      assert is_nil(form.welcome_email)
      assert %Email{} = form.double_opt_in_email
    end

    test "accepts markdown emails without content", %{project: project} do
      form = insert!(:contacts_form, project_id: project.id)

      assert {:ok, form} =
               Contacts.update_form(form.id, %{"welcome_email" => %{"type" => "markdown"}})

      assert %Email{type: :markdown, subject: nil, text_body: nil} = form.welcome_email
    end

    test "enabling an email without content creates an empty email", %{project: project} do
      form = insert!(:contacts_form, project_id: project.id, welcome_email: nil)

      assert {:ok, form} =
               Contacts.update_form(form.id, %{
                 "settings" => %{"id" => form.settings.id, "welcome_enabled" => true}
               })

      assert %Email{
               type: :markdown,
               subject: nil,
               text_body: nil,
               editor_config: %{enable_wysiwyg: false}
             } = form.welcome_email

      assert %Email{} = Contacts.get_form(form.id).welcome_email
    end

    test "disabling an email keeps its content", %{project: project} do
      form =
        insert!(:contacts_form,
          project_id: project.id,
          welcome_email: build(:mailings_email, subject: "Welcome, Peter"),
          settings: %{welcome_enabled: true}
        )

      assert {:ok, form} =
               Contacts.update_form(form.id, %{
                 "settings" => %{"id" => form.settings.id, "welcome_enabled" => false}
               })

      assert %Email{subject: "Welcome, Peter"} = form.welcome_email
    end

    test "rejects templates of other projects", %{project: project, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, %{name: "Other"})
      template = insert!(:template, project_id: other_project.id)
      form = insert!(:contacts_form, project_id: project.id)

      assert {:error, changeset} =
               Contacts.update_form(form.id, %{
                 "welcome_email" => %{
                   "type" => "markdown",
                   "text_body" => "body",
                   "template_id" => template.id
                 }
               })

      assert %{welcome_email: ["template not found"]} = errors_on(changeset)
    end

    test "accepts templates of the same project", %{project: project} do
      template = insert!(:template, project_id: project.id)
      form = insert!(:contacts_form, project_id: project.id)

      assert {:ok, form} =
               Contacts.update_form(form.id, %{
                 "double_opt_in_email" => %{
                   "type" => "markdown",
                   "text_body" => "body",
                   "template_id" => template.id
                 }
               })

      assert form.double_opt_in_email.template_id == template.id
    end
  end
end
