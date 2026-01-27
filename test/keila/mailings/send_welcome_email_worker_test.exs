defmodule Keila.Mailings.SendWelcomeEmailWorkerTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.SendWelcomeEmailWorker
  require Keila

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "Welcome Email Test"})

    %{project: project}
  end

  describe "perform/1" do
    @describetag :welcome_email
    @email "test@example.com"

    test "sends welcome email when enabled", %{project: project} do
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
        assert {:cancel, _} =
                 %Oban.Job{args: %{"contact_id" => contact.id, "form_id" => form.id}}
                 |> SendWelcomeEmailWorker.perform()

        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)

        assert {:ok, _} =
                 %Oban.Job{args: %{"contact_id" => contact.id, "form_id" => form.id}}
                 |> SendWelcomeEmailWorker.perform()
      else
        assert {:ok, _} =
                 %Oban.Job{args: %{"contact_id" => contact.id, "form_id" => form.id}}
                 |> SendWelcomeEmailWorker.perform()
      end

      {:email, email} = assert_received({:email, %{to: [{"", @email}]}})
      assert email.subject == "Welcome to our newsletter!"
      assert email.text_body =~ "Thank you for subscribing"
    end

    test "cancels job when welcome email is disabled", %{project: project} do
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

      assert {:cancel, _} =
               %Oban.Job{args: %{"contact_id" => contact.id, "form_id" => form.id}}
               |> SendWelcomeEmailWorker.perform()

      refute_received({:email, _})
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

      assert {:ok, _} =
               %Oban.Job{args: %{"contact_id" => contact.id, "form_id" => form.id}}
               |> SendWelcomeEmailWorker.perform()

      {:email, email} = assert_received({:email, %{to: [{"", @email}]}})

      # Default subject
      assert email.subject =~ "Welcome!"
      assert email.html_body =~ "Thank you for subscribing"
    end
  end
end
