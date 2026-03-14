defmodule Keila.Mailings.MessageActions.Unsubscription do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Message

  @doc """
  Runs side-effects associated with a message recipient unsubscribing from a project.
  """
  @spec handle(Message.id()) :: :ok
  def handle(message_id) do
    message_id
    |> maybe_update_message()
    |> tap_if_not_nil(&update_contact/1)
    |> tap_if_not_nil(&log_event/1)
  end

  defp maybe_update_message(message_id) do
    from(r in Message,
      where: r.id == ^message_id and is_nil(r.unsubscribed_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [unsubscribed_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  def update_contact(%Message{contact_id: contact_id}) do
    Keila.Contacts.update_contact_status(contact_id, :unsubscribed)
  end

  defp log_event(%Message{id: message_id, contact_id: contact_id}) do
    Keila.Tracking.log_event("unsubscribe", contact_id, message_id, %{})
  end
end
