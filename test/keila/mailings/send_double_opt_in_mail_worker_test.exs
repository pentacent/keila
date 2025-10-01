defmodule Keila.Mailings.SendDoubleOptInMailWorkerTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.SendDoubleOptInMailWorker
  require Keila

  setup do
    user = insert!(:user)
    account = insert!(:account)
    Keila.Accounts.set_user_account(user.id, account.id)
    {:ok, project} = Keila.Projects.create_project(user.id, %{name: "DOI Test"})

    %{project: project}
  end

  describe "perform/1" do
    @describetag :double_opt_in
    @email "test@example.com"
    test "sends double-opt-in email", %{project: project} do
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
        assert {:cancel, _} =
                 %Oban.Job{args: %{"form_params_id" => form_params.id}}
                 |> SendDoubleOptInMailWorker.perform()

        account = Keila.Repo.one(Keila.Accounts.Account)
        KeilaCloud.Accounts.update_account_status(account.id, :active)

        assert {:ok, _} =
                 %Oban.Job{args: %{"form_params_id" => form_params.id}}
                 |> SendDoubleOptInMailWorker.perform()
      else
        assert {:ok, _} =
                 %Oban.Job{args: %{"form_params_id" => form_params.id}}
                 |> SendDoubleOptInMailWorker.perform()
      end

      hmac = Keila.Contacts.double_opt_in_hmac(form.id, form_params.id)

      {:email, email} = assert_received({:email, %{to: [{"", @email}]}})

      assert email.text_body =~
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
