defmodule Keila.Mailings.RecipientActions.Unsubscription do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Recipient

  @doc """
  Runs side-effects associated with a recipient unsubscribing from a project.
  """
  @spec handle(Recipient.id()) :: :ok
  def handle(recipient_id) do
    recipient_id
    |> maybe_update_recipient()
    |> tap_if_not_nil(&update_contact/1)
    |> tap_if_not_nil(&log_event/1)
  end

  defp maybe_update_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.unsubscribed_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [unsubscribed_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  def update_contact(%Recipient{contact_id: contact_id}) do
    Keila.Contacts.update_contact_status(contact_id, :unsubscribed)
  end

  defp log_event(%Recipient{id: recipient_id, contact_id: contact_id}) do
    Keila.Tracking.log_event("unsubscribe", contact_id, recipient_id, %{})
  end
end
