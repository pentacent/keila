defmodule Keila.Mailings.MailingsMessageActionsTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Keila.Contacts

  @tag :mailings
  test "Handle message actions" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    contact = insert!(:contact, project_id: project.id)

    message =
      insert!(:message, project: project, contact_id: contact.id, campaign_id: campaign.id)

    Mailings.handle_message_open(message.id)
    assert Mailings.get_message(message.id).opened_at

    Mailings.handle_message_click(message.id)
    assert Mailings.get_message(message.id).clicked_at

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert Mailings.get_message(message.id).soft_bounce_received_at

    Mailings.handle_message_hard_bounce(message.id, %{})
    assert Mailings.get_message(message.id).hard_bounce_received_at
    assert Contacts.get_contact(contact.id).status == :unreachable

    Mailings.unsubscribe_from_message(message.id)
    assert Mailings.get_message(message.id).unsubscribed_at
    assert Contacts.get_contact(contact.id).status == :unsubscribed
  end

  test "Three soft bounces in the last five messages mark contact as unreachable" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    contact = insert!(:contact, project_id: project.id)

    for n <- 1..5 do
      insert!(:message,
        project: project,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(10 - n)
      )
    end

    message =
      insert!(:message,
        project: project,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(5)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    message =
      insert!(:message,
        project: project,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(4)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    message =
      insert!(:message,
        project: project,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(3)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :unreachable} = Repo.reload(contact)
  end

  @tag :mailings
  test "Bounces and complaints on messages without a contact also work" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    sender = insert!(:mailings_sender, project: project)

    message =
      insert!(:message,
        project: project,
        contact_id: nil,
        campaign_id: nil,
        sender_id: sender.id,
        project_id: project.id,
        sent_at: DateTime.utc_now(:second)
      )

    assert :ok = Mailings.handle_message_hard_bounce(message.id, %{})
    assert Repo.reload(message).hard_bounce_received_at

    assert :ok = Mailings.handle_message_soft_bounce(message.id, %{})
    assert Repo.reload(message).soft_bounce_received_at

    assert :ok = Mailings.handle_message_complaint(message.id, %{})
    assert Repo.reload(message).complaint_received_at
  end

  defp mins_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-5 * n, :minute)
  end
end
