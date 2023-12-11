defmodule Keila.Mailings.SendDoubleOptInMailWorkerTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.SendDoubleOptInMailWorker

  describe "perform/1" do
    @describetag :double_opt_in
    @email "test@example.com"
    test "sends double-opt-in email" do
      project = insert!(:project)

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

      assert {:ok, _} =
               %Oban.Job{args: %{"form_params_id" => form_params.id}}
               |> SendDoubleOptInMailWorker.perform()

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
