defmodule Keila.Mailings.WelcomeMessageTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.WelcomeMessage
  alias Keila.Mailings.Message
  require Keila

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "Welcome Email Test"})

    %{project: project}
  end

  describe "deliver/2" do
    @describetag :welcome_email
    @email "test@example.com"

    test "creates a ready message for welcome email", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Keila.Mailings.Sender.Config{type: "test"}
        )

      form =
        insert!(:contacts_form,
          project_id: project.id,
          sender_id: sender.id,
          settings: %{
            captcha_required: false,
            welcome_enabled: true,
            welcome_subject: "Welcome to our newsletter!",
            welcome_markdown_body: "Thank you for subscribing, {{ contact.first_name }}!"
          }
        )

      contact =
        insert!(:contact,
          project_id: project.id,
          email: @email,
          first_name: "Test",
          last_name: "User"
        )

      Keila.if_cloud do
        # Account needs to be active
        assert {:error, _} = WelcomeMessage.deliver(contact.id, form.id)

        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)

        assert {:ok, message} = WelcomeMessage.deliver(contact.id, form.id)
      else
        assert {:ok, message} = WelcomeMessage.deliver(contact.id, form.id)
      end

      message = Keila.Repo.get!(Message, message.id)

      assert message.status == :ready
      assert message.priority == 10
      assert message.recipient_email == @email
      assert message.project_id == project.id
      assert message.sender_id == sender.id
      assert message.contact_id == contact.id
      assert message.form_id == form.id
      assert message.subject == "Welcome to our newsletter!"
      assert message.html_body =~ "Thank you for subscribing"
      assert message.text_body =~ "Thank you for subscribing"
    end

    test "returns error when welcome email is disabled", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Keila.Mailings.Sender.Config{type: "test"}
        )

      form =
        insert!(:contacts_form,
          project_id: project.id,
          sender_id: sender.id,
          settings: %{
            captcha_required: false,
            welcome_enabled: false
          }
        )

      contact =
        insert!(:contact,
          project_id: project.id,
          email: @email
        )

      Keila.if_cloud do
        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)
      end

      assert {:error, _} = WelcomeMessage.deliver(contact.id, form.id)

      assert is_nil(Keila.Repo.one(Message))
    end

    test "uses default subject and body when not configured", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Keila.Mailings.Sender.Config{type: "test"}
        )

      form =
        insert!(:contacts_form,
          project_id: project.id,
          sender_id: sender.id,
          settings: %{
            captcha_required: false,
            welcome_enabled: true
          }
        )

      contact =
        insert!(:contact,
          project_id: project.id,
          email: @email
        )

      Keila.if_cloud do
        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)
      end

      assert {:ok, message} = WelcomeMessage.deliver(contact.id, form.id)

      message = Keila.Repo.get!(Message, message.id)

      assert message.subject =~ "Welcome!"
      assert message.html_body =~ "Thank you for subscribing"
    end
  end
end
