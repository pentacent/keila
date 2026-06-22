defmodule Keila.Mailings.TransactionalMessageTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.TransactionalMessage
  alias Keila.Mailings.Message
  alias Keila.Mailings.Renderer.Output

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))

    sender = insert!(:mailings_sender, project_id: project.id)

    %{project: project, other_project: other_project, sender: sender}
  end

  describe "deliver/2" do
    @tag :transactional_message
    test "persists a :ready message with the resolved envelope",
         %{project: project, sender: sender} do
      assert {:ok, %Message{} = message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hello",
                 "text_body" => "Hi"
               })

      assert message.recipient_email == "to@example.com"
      assert message.subject == "Hello"
      assert message.text_body == "Hi"
      assert message.status == :ready
      assert message.priority == 50
      assert message.project_id == project.id
      assert message.sender_id == sender.id
    end

    @tag :transactional_message
    test "uses the request's text_body when present", %{project: project, sender: sender} do
      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_body" => "Hello {{ contact.email }}"
               })

      assert message.text_body =~ "Hello to@example.com"
      assert is_nil(message.html_body)
    end

    @tag :transactional_message
    test "falls back to template.text_body", %{project: project, sender: sender} do
      template =
        insert!(:template, project_id: project.id, type: :text, text_body: "Hi from template")

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "S"
               })

      assert message.text_body == "Hi from template"
    end

    @tag :transactional_message
    test "uses the request's html_body and interpolates Liquid",
         %{project: project, sender: sender} do
      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "html",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "html_body" => "<p>Hi {{ contact.email }}</p>"
               })

      assert message.html_body =~ "Hi to@example.com"
      assert message.text_body =~ "Hi to@example.com"
    end

    @tag :transactional_message
    test "falls back to template.html_body", %{project: project, sender: sender} do
      template =
        insert!(:template,
          project_id: project.id,
          type: :html,
          html_body: "<p>From the template</p>"
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "html",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi"
               })

      assert message.html_body =~ "From the template"
    end

    @tag :transactional_message
    test "compiles raw mjml_body from the request",
         %{project: project, sender: sender} do
      mjml = """
      <mjml><mj-body>
        <mj-section><mj-column>
          <mj-text>Hello {{ contact.email }}</mj-text>
        </mj-column></mj-section>
      </mj-body></mjml>
      """

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "mjml",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "mjml_body" => mjml
               })

      assert message.html_body =~ "Hello to@example.com"
      assert message.text_body =~ "Hello to@example.com"
    end

    @tag :transactional_message
    test "fills slots from mjml_content in an mjml template",
         %{project: project, sender: sender} do
      template =
        insert!(:template,
          project_id: project.id,
          type: :mjml,
          mjml_body: """
          <mjml><mj-body>
            <keila-content name="test">
              <mj-section><mj-column><mj-text>Default</mj-text></mj-column></mj-section>
            </keila-content>
          </mj-body></mjml>
          """
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "mjml",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "mjml_content" => %{
                   "test" =>
                     "<mj-section><mj-column><mj-text>Filled</mj-text></mj-column></mj-section>"
                 }
               })

      assert message.html_body =~ "Filled"
      refute message.html_body =~ "Default"
    end

    @tag :transactional_message
    test "fills slots from html_content in an html template",
         %{project: project, sender: sender} do
      template =
        insert!(:template,
          project_id: project.id,
          type: :html,
          html_body: ~s(<div><keila-content name="test"><p>Default</p></keila-content></div>)
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "html",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "html_content" => %{"test" => "<p>Filled</p>"}
               })

      assert message.html_body =~ "Filled"
      refute message.html_body =~ "Default"
    end

    @tag :transactional_message
    test "fills slots from text_content in a text template",
         %{project: project, sender: sender} do
      template =
        insert!(:template,
          project_id: project.id,
          type: :text,
          text_body: ~s(Hello <keila-content name="test">Default</keila-content>)
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_content" => %{"test" => "Filled"}
               })

      assert message.text_body =~ "Filled"
      refute message.text_body =~ "Default"
    end

    @tag :transactional_message
    test "variables get merged into Liquid assigns", %{project: project, sender: sender} do
      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_body" => "Order #{1} for {{ customer_name }}",
                 "variables" => %{"customer_name" => "Peter"}
               })

      assert message.text_body =~ "Peter"
    end

    @tag :transactional_message
    test "uses explicit subject when given", %{project: project, sender: sender} do
      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Custom Subject",
                 "text_body" => "yo"
               })

      assert message.subject == "Custom Subject"
    end

    @tag :transactional_message
    test "falls back to template name when subject is absent",
         %{project: project, sender: sender} do
      template =
        insert!(:template, project_id: project.id, type: :text, name: "Welcome", text_body: "yo")

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com"
               })

      assert message.subject == "Welcome"
    end

    @tag :transactional_message
    test "by contact_id attaches contact and uses its email when recipient_email is absent",
         %{project: project, sender: sender} do
      contact =
        insert!(:contact,
          project_id: project.id,
          email: "real@example.com",
          first_name: "Real",
          last_name: "Person"
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "contact_id" => contact.id,
                 "subject" => "Hi",
                 "text_body" => "yo"
               })

      assert message.recipient_email == "real@example.com"
      assert message.recipient_name == "Real Person"
      assert message.contact_id == contact.id
    end

    @tag :transactional_message
    test "recipient_email overrides contact.email but keeps contact_id link",
         %{project: project, sender: sender} do
      contact = insert!(:contact, project_id: project.id, email: "real@example.com")

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "contact_id" => contact.id,
                 "recipient_email" => "override@example.com",
                 "subject" => "Hi",
                 "text_body" => "yo"
               })

      assert message.recipient_email == "override@example.com"
      assert message.contact_id == contact.id
    end

    @tag :transactional_message
    test "external_contact_id resolves to a contact", %{project: project, sender: sender} do
      contact =
        insert!(:contact,
          project_id: project.id,
          email: "ext@example.com",
          external_id: "ext-123"
        )

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "external_contact_id" => "ext-123",
                 "subject" => "Hi",
                 "text_body" => "yo"
               })

      assert message.contact_id == contact.id
      assert message.recipient_email == "ext@example.com"
    end

    @tag :transactional_message
    test "recipient_email auto-links to contact when one exists",
         %{project: project, sender: sender} do
      contact =
        insert!(:contact, project_id: project.id, email: "found@example.com")

      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "found@example.com",
                 "subject" => "Hi",
                 "text_body" => "yo"
               })

      assert message.contact_id == contact.id
    end

    @tag :transactional_message
    test "recipient_email without a matching contact still works (contact_id nil)",
         %{project: project, sender: sender} do
      assert {:ok, message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "stranger@example.com",
                 "subject" => "Hi",
                 "text_body" => "yo"
               })

      assert is_nil(message.contact_id)
      assert message.recipient_email == "stranger@example.com"
    end

    @tag :transactional_message
    test "accepts cc/bcc as a string or a list and stores canonical addresses",
         %{project: project, sender: sender} do
      assert {:ok, %Message{} = message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_body" => "hi",
                 "cc" => "Peter <peter@example.com>, lois@example.com",
                 "bcc" => ["stewie@example.com"]
               })

      assert message.cc == ["Peter <peter@example.com>", "lois@example.com"]
      assert message.bcc == ["stewie@example.com"]
    end

    @tag :transactional_message
    test "does not inject an unsubscribe link", %{project: project, sender: sender} do
      assert {:ok, %Message{} = message} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_body" => "Unsubscribe: {{ unsubscribe_link }}"
               })

      assert message.text_body == "Unsubscribe: "
    end

    @tag :transactional_message
    test "rejects when type is missing", %{project: project, sender: sender} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com"
               })

      assert "can't be blank" in errors_on(cs).type
    end

    @tag :transactional_message
    test "rejects when sender_id is missing", %{project: project} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "recipient_email" => "to@example.com",
                 "text_body" => "Hi"
               })

      assert "can't be blank" in errors_on(cs).sender_id
    end

    @tag :transactional_message
    test "rejects when none of contact_id / external_contact_id / recipient_email is given",
         %{project: project, sender: sender} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "text_body" => "Hi"
               })

      assert Enum.any?(errors_on(cs).contact_id, &String.contains?(&1, "required"))
    end

    @tag :transactional_message
    test "rejects malformed recipient_email", %{project: project, sender: sender} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "nope",
                 "text_body" => "Hi"
               })

      assert "is not a valid email address" in errors_on(cs).recipient_email
    end

    @tag :transactional_message
    test "rejects an invalid cc address", %{project: project, sender: sender} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "text_body" => "hi",
                 "cc" => "@@ not valid @@"
               })

      assert errors_on(cs)[:cc]
    end

    @tag :transactional_message
    test "rejects when neither a body nor a template is given",
         %{project: project, sender: sender} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "S"
               })

      assert "can't be blank without a template" in errors_on(cs).text_body
    end

    @tag :transactional_message
    test "returns :no_subject when neither the request nor template supply a subject",
         %{project: project, sender: sender} do
      assert {:error, :no_subject} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "text_body" => "yo"
               })
    end

    @tag :transactional_message
    test "markdown and block are not yet supported", %{project: project, sender: sender} do
      for type <- ["markdown", "block"] do
        assert {:error, %Ecto.Changeset{} = cs} =
                 TransactionalMessage.deliver(project.id, %{
                   "type" => type,
                   "sender_id" => sender.id,
                   "recipient_email" => "to@example.com",
                   "subject" => "Hi",
                   "text_body" => "Hi",
                   "json_body" => %{}
                 })

        assert "is not supported" in errors_on(cs).type
      end
    end

    @tag :transactional_message
    test "returns :sender_not_found when sender_id doesn't belong to project",
         %{project: project, other_project: other} do
      other_sender = insert!(:mailings_sender, project_id: other.id)

      assert {:error, :sender_not_found} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => other_sender.id,
                 "recipient_email" => "to@example.com",
                 "text_body" => "Hi"
               })
    end

    @tag :transactional_message
    test "returns :template_not_found when template_id doesn't belong to project",
         %{project: project, sender: sender, other_project: other} do
      other_template = insert!(:template, project_id: other.id, type: :text)

      assert {:error, :template_not_found} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "template_id" => other_template.id,
                 "recipient_email" => "to@example.com"
               })
    end

    @tag :transactional_message
    test "contact_id not in project returns :contact_not_found",
         %{project: project, sender: sender, other_project: other} do
      other_contact = insert!(:contact, project_id: other.id)

      assert {:error, :contact_not_found} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "contact_id" => other_contact.id,
                 "subject" => "Hi",
                 "text_body" => "yo"
               })
    end

    @tag :transactional_message
    test "external_contact_id not found returns :contact_not_found",
         %{project: project, sender: sender} do
      assert {:error, :contact_not_found} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "external_contact_id" => "missing",
                 "subject" => "Hi",
                 "text_body" => "yo"
               })
    end

    @tag :transactional_message
    test "render failure returns {:rendering_failed, _} and persists nothing",
         %{project: project, sender: sender} do
      assert {:error, {:rendering_failed, _}} =
               TransactionalMessage.deliver(project.id, %{
                 "type" => "mjml",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "mjml_body" => "<mjml><mj-body><mj-text>{{ broken </mj-text></mj-body></mjml>"
               })

      assert is_nil(Keila.Repo.one(Message))
    end
  end

  describe "preview/2" do
    @tag :transactional_message
    test "renders the subject and body and returns a valid output",
         %{project: project, sender: sender} do
      assert {:ok, %Output{valid?: true} = output} =
               TransactionalMessage.preview(project.id, %{
                 "type" => "text",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hello {{ contact.email }}",
                 "text_body" => "Hi {{ contact.email }}"
               })

      assert output.subject == "Hello to@example.com"
      assert output.text_body =~ "Hi to@example.com"
    end

    @tag :transactional_message
    test "renders template slot content like deliver/2 without persisting a message",
         %{project: project, sender: sender} do
      template =
        insert!(:template,
          project_id: project.id,
          type: :html,
          html_body: ~s(<div><keila-content name="test"><p>Default</p></keila-content></div>)
        )

      assert {:ok, %Output{valid?: true} = output} =
               TransactionalMessage.preview(project.id, %{
                 "type" => "html",
                 "sender_id" => sender.id,
                 "template_id" => template.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "html_content" => %{"test" => "<p>Filled</p>"}
               })

      assert output.html_body =~ "Filled"
      refute output.html_body =~ "Default"

      assert is_nil(Keila.Repo.one(Message))
    end

    @tag :transactional_message
    test "returns an invalid output when rendering fails",
         %{project: project, sender: sender} do
      assert {:ok, %Output{valid?: false, errors: [_ | _]}} =
               TransactionalMessage.preview(project.id, %{
                 "type" => "mjml",
                 "sender_id" => sender.id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hi",
                 "mjml_body" => "<mjml><mj-body><mj-text>{{ broken </mj-text></mj-body></mjml>"
               })
    end

    @tag :transactional_message
    test "returns {:error, reason} when an association can't be loaded",
         %{project: project, other_project: other} do
      other_sender = insert!(:mailings_sender, project_id: other.id)

      assert {:error, :sender_not_found} =
               TransactionalMessage.preview(project.id, %{
                 "type" => "text",
                 "sender_id" => other_sender.id,
                 "recipient_email" => "to@example.com",
                 "text_body" => "Hi"
               })
    end

    @tag :transactional_message
    test "returns {:error, changeset} for invalid params", %{project: project} do
      assert {:error, %Ecto.Changeset{} = cs} =
               TransactionalMessage.preview(project.id, %{
                 "recipient_email" => "to@example.com"
               })

      assert "can't be blank" in errors_on(cs).type
    end
  end
end
