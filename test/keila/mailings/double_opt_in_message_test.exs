defmodule Keila.Mailings.DoubleOptInMessageTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.DoubleOptInMessage
  alias Keila.Mailings.Message
  require Keila

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "DOI Test"})

    %{project: project, account: account}
  end

  describe "deliver/1" do
    @describetag :double_opt_in
    @email "test@example.com"
    test "creates a ready message for double-opt-in email", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Keila.Mailings.Sender.Config{type: "test"}
        )

      form =
        insert!(:contacts_form,
          project_id: project.id,
          sender_id: sender.id,
          settings: %{captcha_required: false, double_opt_in_required: true}
        )

      form_params =
        insert!(:contacts_form_params, %{
          project_id: project.id,
          form_id: form.id,
          params: %{"email" => @email}
        })

      Keila.if_cloud do
        # Account needs to be active
        assert {:error, _} = DoubleOptInMessage.deliver(form_params.id)

        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)

        assert {:ok, message} = DoubleOptInMessage.deliver(form_params.id)
      else
        assert {:ok, message} = DoubleOptInMessage.deliver(form_params.id)
      end

      message = Keila.Repo.get!(Message, message.id)

      assert message.status == :ready
      assert message.priority == 10
      assert message.recipient_email == @email
      assert message.project_id == project.id
      assert message.sender_id == sender.id
      assert message.form_id == form.id
      assert message.form_params_id == form_params.id
      assert message.subject
      assert message.html_body
      assert message.text_body

      hmac = Keila.Contacts.double_opt_in_hmac(form.id, form_params.id)

      assert message.text_body =~
               KeilaWeb.Router.Helpers.public_form_url(
                 KeilaWeb.Endpoint,
                 :double_opt_in,
                 form.id,
                 form_params.id,
                 hmac
               )
    end
  end
end
