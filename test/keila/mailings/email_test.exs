defmodule Keila.Mailings.EmailTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.Email
  alias Keila.Mailings.Renderer

  describe "changeset/2" do
    test "requires a type" do
      changeset = Email.changeset(%Email{}, %{subject: "Hello"})
      refute changeset.valid?
      assert %{type: _} = errors_on(changeset)

      changeset =
        Email.changeset(%Email{}, %{type: :markdown, subject: "Hello", text_body: "Body"})

      assert changeset.valid?
    end

    test "rejects unknown types" do
      changeset = Email.changeset(%Email{}, %{type: :hybrid})

      refute changeset.valid?
      assert %{type: _} = errors_on(changeset)
    end

    test "casts the editor config" do
      email =
        %Email{}
        |> Email.changeset(%{type: :markdown, editor_config: %{enable_wysiwyg: false}})
        |> Ecto.Changeset.apply_changes()

      assert %Email.EditorConfig{enable_wysiwyg: false} = email.editor_config
    end
  end

  describe "subject validation" do
    test "requires a subject without a template" do
      changeset = Email.changeset(%Email{}, %{type: :text, text_body: "Hi"})
      refute changeset.valid?
      assert %{subject: ["can't be blank when no template is set"]} = errors_on(changeset)

      changeset = Email.changeset(%Email{}, %{type: :text, text_body: "Hi", template_id: "tpl_1"})
      assert changeset.valid?
    end

    test "require_content: false allows emails without a subject" do
      changeset =
        Email.changeset(%Email{}, %{type: :markdown, text_body: "Hi"}, require_content: false)

      assert changeset.valid?
    end
  end

  describe "body validation" do
    test "requires the appropriate body for the type" do
      for {type, body_field, body} <- [
            {:text, :text_body, "body"},
            {:markdown, :text_body, "body"},
            {:html, :html_body, "body"},
            {:mjml, :mjml_body, "body"},
            {:block, :json_body, %{"blocks" => []}}
          ] do
        changeset = Email.changeset(%Email{}, %{type: type})
        refute changeset.valid?
        assert Map.has_key?(errors_on(changeset), body_field)

        changeset =
          Email.changeset(%Email{}, %{:type => type, :subject => "Hi", body_field => body})

        assert changeset.valid?
      end
    end

    test "text, html, and mjml templates can supply the body" do
      for type <- [:text, :html, :mjml] do
        changeset = Email.changeset(%Email{}, %{type: type, template_id: "tpl_1"})
        assert changeset.valid?
      end
    end

    test "require_content: false allows markdown emails without a body" do
      changeset = Email.changeset(%Email{}, %{type: :markdown}, require_content: false)
      assert changeset.valid?

      changeset = Email.changeset(%Email{}, %{type: :html}, require_content: false)
      refute changeset.valid?
      assert %{html_body: _} = errors_on(changeset)
    end

    test "markdown and block emails need a body even with a template" do
      changeset = Email.changeset(%Email{}, %{type: :markdown, template_id: "tpl_1"})
      refute changeset.valid?
      assert %{text_body: _} = errors_on(changeset)

      changeset = Email.changeset(%Email{}, %{type: :block, template_id: "tpl_1"})
      refute changeset.valid?
      assert %{json_body: _} = errors_on(changeset)
    end
  end

  describe "to_input/3" do
    test "maps the content fields and adds a campaign assign" do
      template = build(:template)

      email =
        build(:mailings_email,
          subject: "Hello {{ contact.first_name }}",
          preview_text: "Preview",
          text_body: "Hi {{ contact.first_name }}!",
          template: template
        )

      contact = build(:contact, first_name: "Lois")

      assert %Renderer.Input{
               type: :markdown,
               subject: "Hello {{ contact.first_name }}",
               text_body: "Hi {{ contact.first_name }}!",
               template: ^template,
               contact: ^contact,
               assigns: %{
                 "campaign" => %{
                   "subject" => "Hello {{ contact.first_name }}",
                   "preview_text" => "Preview"
                 }
               }
             } = Email.to_input(email, contact)

      input = Email.to_input(email, nil, %{"campaign" => %{"subject" => "Custom"}})
      assert input.assigns["campaign"]["subject"] == "Custom"
    end

    test "accepts a {name, email} tuple as recipient" do
      email = build(:mailings_email)

      assert %Renderer.Input{
               contact: nil,
               recipient_name: "Peter Griffin",
               recipient_email: "peter@example.com"
             } = Email.to_input(email, {"Peter Griffin", "peter@example.com"})
    end
  end
end
