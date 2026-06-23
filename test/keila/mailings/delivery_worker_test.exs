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
    sender = insert!(:mailings_sender, project_id: project.id, config: %{type: "test"})

    %{project: project, sender: sender}
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

    @tag :mailings_worker
    test "cc and bcc are applied to the email", %{project: project, sender: sender} do
      message =
        insert!(:message,
          project_id: project.id,
          sender_id: sender.id,
          status: :queued,
          cc: ["cc@example.com"],
          bcc: ["bcc@example.com"]
        )

      assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => message.id})

      assert_receive {:email, email}
      assert email.cc == [{"", "cc@example.com"}]
      assert email.bcc == [{"", "bcc@example.com"}]
    end
  end

  @tag :mailings_worker
  test "campaign message to a contact gets List-Unsubscribe and Precedence: Bulk",
       %{project: project, sender: sender} do
    contact = insert!(:contact, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    message =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id,
        campaign_id: campaign.id
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => message.id})

    assert_receive {:email, email}
    assert email.headers["List-Unsubscribe"] =~ ~r"<.*/unsubscribe/.*>"
    assert email.headers["Precedence"] == "Bulk"
  end

  @tag :mailings_worker
  test "form message to a contact gets List-Unsubscribe", %{project: project, sender: sender} do
    contact = insert!(:contact, project_id: project.id)
    form = insert!(:contacts_form, project_id: project.id)

    message =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id,
        form_id: form.id
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => message.id})

    assert_receive {:email, email}
    assert email.headers["List-Unsubscribe"] =~ ~r"<.*/unsubscribe/.*>"
  end

  @tag :mailings_worker
  test "transactional message to a contact gets no List-Unsubscribe or Precedence header",
       %{project: project, sender: sender} do
    contact = insert!(:contact, project_id: project.id)

    message =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => message.id})

    assert_receive {:email, email}
    refute Map.has_key?(email.headers, "List-Unsubscribe")
    refute Map.has_key?(email.headers, "Precedence")
  end

  @tag :mailings_worker
  test "a custom List-Unsubscribe is preserved and not duplicated, even with different casing",
       %{project: project, sender: sender} do
    contact = insert!(:contact, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    message =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id,
        campaign_id: campaign.id,
        headers: %{"list-unsubscribe" => "<https://example.com/custom>"}
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => message.id})

    assert_receive {:email, email}
    assert email.headers["list-unsubscribe"] == "<https://example.com/custom>"
    refute Map.has_key?(email.headers, "List-Unsubscribe")
  end

  @tag :mailings_worker
  test "a custom https List-Unsubscribe gets one-click; mailto does not",
       %{project: project, sender: sender} do
    contact = insert!(:contact, project_id: project.id)

    https =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id,
        headers: %{"List-Unsubscribe" => "<https://example.com/custom>"}
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => https.id})
    assert_receive {:email, https_email}
    assert https_email.headers["List-Unsubscribe"] == "<https://example.com/custom>"
    assert https_email.headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click"

    mailto =
      insert!(:message,
        project_id: project.id,
        sender_id: sender.id,
        status: :queued,
        contact_id: contact.id,
        headers: %{"List-Unsubscribe" => "<mailto:unsubscribe@example.com>"}
      )

    assert :ok = perform_job(Keila.Mailings.DeliveryWorker, %{"message_id" => mailto.id})
    assert_receive {:email, mailto_email}
    assert mailto_email.headers["List-Unsubscribe"] == "<mailto:unsubscribe@example.com>"
    refute Map.has_key?(mailto_email.headers, "List-Unsubscribe-Post")
  end

  defp get_message_for_contact(campaign_id, contact_id) do
    import Ecto.Query

    from(r in Message,
      where: r.campaign_id == ^campaign_id and r.contact_id == ^contact_id
    )
    |> Keila.Repo.one()
  end
end
