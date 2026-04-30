defmodule Keila.Mailings.DeliveryWorkerTest do
  use Keila.DataCase, async: true
  use Keila.Repo
  use Oban.Testing, repo: Keila.Repo

  alias Keila.{Projects, Mailings}
  alias Keila.Mailings.Message

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))
    %{project: project}
  end

  describe "perform/1" do
    @tag :mailings_worker
    @invalid_emails ["invalid-email", "foo@-invalid-domain", "foo@invalid.com;", " "]
    test "sets failed_at and contact status to unreachable for invalid email address", %{
      project: project
    } do
      contacts =
        for email <- @invalid_emails, do: insert!(:contact, project_id: project.id, email: email)

      # Use the SMTP adapter because the test adapter doesn't parse the email address.
      sender =
        insert!(:mailings_sender,
          config: %Mailings.Sender.Config{type: "smtp", smtp_relay: "localhost"}
        )

      campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

      assert :ok = Mailings.deliver_campaign(campaign.id)
      assert %{success: 1} = Oban.drain_queue(queue: :campaign_renderer)
      assert :ok = schedule_messages()

      jobs =
        Keila.Repo.all(from(j in Oban.Job, where: j.queue == "mailer"))

      for job <- jobs do
        assert {:cancel, :invalid_email} = Keila.Mailings.DeliveryWorker.perform(job)
      end

      for contact <- contacts do
        message = get_message_for_contact(campaign.id, contact.id)
        assert message.failed_at

        contact = Repo.reload(contact)
        assert contact.status == :unreachable
      end
    end

    @tag :mailings_worker
    test "sets failed_at and contact status to unreachable for invalid email domain", %{
      project: project
    } do
      contact = insert!(:contact, project_id: project.id, email: "foo@-invalid-domain")

      # Use the SMTP adapter because the test adapter doesn't parse the email address.
      sender =
        insert!(:mailings_sender,
          config: %Mailings.Sender.Config{type: "smtp", smtp_relay: "localhost"}
        )

      campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

      assert :ok = Mailings.deliver_campaign(campaign.id)
      assert %{success: 1} = Oban.drain_queue(queue: :campaign_renderer)
      assert :ok = schedule_messages()

      job =
        Keila.Repo.one(from(j in Oban.Job, where: j.queue == "mailer"))

      assert {:cancel, _} = Keila.Mailings.DeliveryWorker.perform(job)

      message = get_message_for_contact(campaign.id, contact.id)
      assert message.failed_at

      contact = Repo.reload(contact)
      assert contact.status == :unreachable
    end
  end

  defp get_message_for_contact(campaign_id, contact_id) do
    import Ecto.Query

    from(r in Message,
      where: r.campaign_id == ^campaign_id and r.contact_id == ^contact_id
    )
    |> Keila.Repo.one()
  end
end
