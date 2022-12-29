defmodule Keila.Mailings.RecipientActions.Complaint do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Recipient

  @doc """
  Runs side-effects associated with a recipient opening an email.
  """
  @spec handle(Recipient.id(), map()) :: :ok
  def handle(recipient_id, data) do
    recipient_id
    |> maybe_update_recipient()
    |> tap_if_not_nil(&update_contact(&1))
    |> tap_if_not_nil(&log_event(&1, data))
  end

  defp maybe_update_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.complaint_received_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [complaint_received_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  def update_contact(%Recipient{contact_id: contact_id}) do
    Keila.Contacts.update_contact_status(contact_id, :unsubscribed)
  end

  defp log_event(%Recipient{id: recipient_id, contact_id: contact_id}, data) do
    Keila.Tracking.log_event("complaint", contact_id, recipient_id, data)
  end
end
