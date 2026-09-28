defmodule Keila.Mailings.EmailTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.Email
  alias Keila.Mailings.Renderer

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "Email Test"})

    %{project: project}
  end

  describe "creation_changeset/3" do
    test "sets the project and requires a type", %{project: project} do
      changeset = Email.creation_changeset(%Email{}, %{subject: "Hello"}, project.id)
      refute changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :project_id) == project.id
      assert %{type: _} = errors_on(changeset)

      changeset =
        Email.creation_changeset(
          %Email{},
          %{type: :markdown, subject: "Hello", text_body: "Body"},
          project.id
        )

      assert changeset.valid?
    end

    test "rejects unknown types", %{project: project} do
      changeset = Email.creation_changeset(%Email{}, %{type: :hybrid}, project.id)

      refute changeset.valid?
      assert %{type: _} = errors_on(changeset)
    end

    test "casts the editor config", %{project: project} do
      email =
        %Email{}
        |> Email.creation_changeset(
          %{type: :markdown, editor_config: %{enable_wysiwyg: false}},
          project.id
        )
        |> Ecto.Changeset.apply_changes()

      assert %Email.EditorConfig{enable_wysiwyg: false} = email.editor_config
    end
  end

  describe "update_changeset/2" do
    test "does not change the project", %{project: project} do
      existing = build(:mailings_email, project_id: project.id)
      changeset = Email.update_changeset(existing, %{"subject" => "New", "project_id" => "other"})

      assert Ecto.Changeset.get_field(changeset, :project_id) == project.id
      assert Ecto.Changeset.get_change(changeset, :subject) == "New"
    end
  end

  describe "body validation" do
    test "requires the body for the type", %{project: project} do
      for {type, body_field, body} <- [
            {:text, :text_body, "body"},
            {:markdown, :text_body, "body"},
            {:html, :html_body, "body"},
            {:mjml, :mjml_body, "body"},
            {:block, :json_body, %{"blocks" => []}}
          ] do
        changeset = Email.creation_changeset(%Email{}, %{type: type}, project.id)
        refute changeset.valid?
        assert Map.has_key?(errors_on(changeset), body_field)

        changeset =
          Email.creation_changeset(%Email{}, %{:type => type, body_field => body}, project.id)

        assert changeset.valid?
      end
    end

    test "text, html, and mjml templates can supply the body", %{project: project} do
      for type <- [:text, :html, :mjml] do
        changeset =
          Email.creation_changeset(%Email{}, %{type: type, template_id: "tpl_1"}, project.id)

        assert changeset.valid?
      end
    end

    test "markdown and block emails need a body even with a template", %{project: project} do
      changeset =
        Email.creation_changeset(%Email{}, %{type: :markdown, template_id: "tpl_1"}, project.id)

      refute changeset.valid?
      assert %{text_body: _} = errors_on(changeset)

      changeset =
        Email.creation_changeset(%Email{}, %{type: :block, template_id: "tpl_1"}, project.id)

      refute changeset.valid?
      assert %{json_body: _} = errors_on(changeset)
    end
  end

  describe "to_input/3" do
    test "maps the content fields, adds a campaign assign, and renders", %{project: project} do
      template = insert!(:template, project_id: project.id)

      email =
        build(:mailings_email,
          project_id: project.id,
          subject: "Hello {{ contact.first_name }}",
          preview_text: "Preview",
          text_body: "Hi {{ contact.first_name }}!",
          template_id: template.id,
          template: template
        )

      contact = build(:contact, first_name: "Lois")

      assert %Renderer.Input{
               type: :markdown,
               subject: "Hello {{ contact.first_name }}",
               text_body: "Hi {{ contact.first_name }}!",
               template: ^template,
               contact: ^contact,
               assigns: %{"campaign" => %{"subject" => "Hello {{ contact.first_name }}"}}
             } = input = Email.to_input(email, contact)

      output = Renderer.render_preview(input)
      assert output.valid?
      assert output.subject == "Hello Lois"
      assert output.html_body =~ "Hi Lois!"
      assert output.text_body =~ "Hi Lois!"

      input = Email.to_input(email, nil, %{"campaign" => %{"subject" => "Custom"}})
      assert input.assigns["campaign"]["subject"] == "Custom"
    end

    test "accepts a {name, email} tuple as recipient", %{project: project} do
      email = build(:mailings_email, project_id: project.id, template: nil)

      assert %Renderer.Input{
               contact: nil,
               recipient_name: "Peter Griffin",
               recipient_email: "peter@example.com"
             } = input = Email.to_input(email, {"Peter Griffin", "peter@example.com"})

      assert input.assigns["contact"] == nil

      output = Renderer.render_preview(%{input | subject: "Hi {{ contact.display_name }}"})
      assert output.valid?
      assert output.subject == "Hi Peter Griffin"
    end
  end
end
