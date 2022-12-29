defmodule Keila.Mailings.MailingsRecipientActionsTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Keila.Contacts

  @tag :mailings
  test "Handle recipient actions" do
    project = insert!(:project)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    contact = insert!(:contact, project_id: project.id)
    recipient = insert!(:mailings_recipient, contact_id: contact.id, campaign_id: campaign.id)

    Mailings.handle_recipient_open(recipient.id)
    assert Mailings.get_recipient(recipient.id).opened_at

    Mailings.handle_recipient_click(recipient.id)
    assert Mailings.get_recipient(recipient.id).clicked_at

    Mailings.handle_recipient_soft_bounce(recipient.id, %{})
    assert Mailings.get_recipient(recipient.id).soft_bounce_received_at

    Mailings.handle_recipient_hard_bounce(recipient.id, %{})
    assert Mailings.get_recipient(recipient.id).hard_bounce_received_at
    assert Contacts.get_contact(contact.id).status == :unreachable

    Mailings.unsubscribe_recipient(recipient.id)
    assert Mailings.get_recipient(recipient.id).unsubscribed_at
    assert Contacts.get_contact(contact.id).status == :unsubscribed
  end
end
