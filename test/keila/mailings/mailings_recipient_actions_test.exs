defmodule Keila.Mailings.MailingsRecipientActionsTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Keila.Contacts

  @tag :mailings
  test "Handle recipient actions" do
    group = insert!(:group)
    project = insert!(:project, group: group)
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

  test "Three soft bounces in the last five recipients mark contact as unreachable" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    contact = insert!(:contact, project_id: project.id)

    recipient =
      insert!(:mailings_recipient,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(5)
      )

    Mailings.handle_recipient_soft_bounce(recipient.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    recipient =
      insert!(:mailings_recipient,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(4)
      )

    Mailings.handle_recipient_soft_bounce(recipient.id, %{})
    assert %{status: :active} = Repo.reload(contact)

    recipient =
      insert!(:mailings_recipient,
        contact_id: contact.id,
        campaign_id: campaign.id,
        sent_at: mins_ago(3)
      )

    Mailings.handle_recipient_soft_bounce(recipient.id, %{})
    assert %{status: :unreachable} = Repo.reload(contact)
  end

  defp mins_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-5 * n, :minute)
  end
end
