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
    message = insert!(:message, contact_id: contact.id, campaign_id: campaign.id)

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

    message =
      insert!(:message,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(5)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    message =
      insert!(:message,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(4)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    message =
      insert!(:message,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(3)
      )

    Mailings.handle_message_soft_bounce(message.id, %{})
    assert %{status: :unreachable} = Repo.reload(contact)
  end

  defp mins_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-5 * n, :minute)
  end
end
