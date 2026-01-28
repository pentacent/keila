defmodule Keila.Mailings.WorkerTest do
  use Keila.DataCase, async: true
  use Oban.Testing, repo: Keila.Repo

  alias Keila.{Projects, Mailings}
  alias Keila.Mailings.Recipient

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  describe "perform/1" do
    @tag :mailings_worker
    test "sets failed_at and contact status to unreachable for invalid email address", %{
      project: project
    } do
      contact = insert!(:contact, project_id: project.id, email: "invalid-email")

      # Use the SMTP adapter because the test adapter doesn't parse the email address.
      sender =
        insert!(:mailings_sender,
          config: %Mailings.Sender.Config{type: "smtp", smtp_relay: "localhost"}
        )

      campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

      assert :ok = Mailings.deliver_campaign(campaign.id)
      assert %{success: 1} = Oban.drain_queue(queue: :mailer_scheduler)
      assert %{cancelled: 1} = Oban.drain_queue(queue: :mailer, with_scheduled: true)

      recipient = get_recipient_for_contact(campaign.id, contact.id)
      assert recipient.failed_at

      contact = Repo.reload(contact)
      assert contact.status == :unreachable
    end

    @tag :mailings_worker
    test "sets failed_at but does not change contact status for template rendering error", %{
      project: project
    } do
      contact = insert!(:contact, project_id: project.id)
      sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})

      campaign =
        insert!(:mailings_campaign,
          project_id: project.id,
          sender_id: sender.id,
          text_body: "Hello {{ 1 | divided_by: 0 }}",
          settings: %Mailings.Campaign.Settings{type: :text}
        )

      assert :ok = Mailings.deliver_campaign(campaign.id)
      assert %{success: 1} = Oban.drain_queue(queue: :mailer_scheduler)
      assert %{cancelled: 1} = Oban.drain_queue(queue: :mailer, with_scheduled: true)

      recipient = get_recipient_for_contact(campaign.id, contact.id)
      assert recipient.failed_at

      # Verify contact status did NOT change (should still be active)
      contact = Repo.reload(contact)
      assert contact.status == :active
    end
  end

  defp get_recipient_for_contact(campaign_id, contact_id) do
    import Ecto.Query

    from(r in Recipient,
      where: r.campaign_id == ^campaign_id and r.contact_id == ^contact_id
    )
    |> Keila.Repo.one()
  end
end
