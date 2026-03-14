defmodule Keila.Mailings.MessageActions.Complaint do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Message

  @doc """
  Runs side-effects associated with receiving a complaint for a message.
  """
  @spec handle(Message.id(), map()) :: :ok
  def handle(message_id, data) do
    message_id
    |> maybe_update_message()
    |> tap_if_not_nil(&update_contact(&1))
    |> tap_if_not_nil(&log_event(&1, data))
  end

  defp maybe_update_message(message_id) do
    from(r in Message,
      where: r.id == ^message_id and is_nil(r.complaint_received_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [complaint_received_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  def update_contact(%Message{contact_id: contact_id}) do
    Keila.Contacts.update_contact_status(contact_id, :unsubscribed)
  end

  defp log_event(%Message{id: message_id, contact_id: contact_id}, data) do
    Keila.Tracking.log_event("complaint", contact_id, message_id, data)
  end
end
