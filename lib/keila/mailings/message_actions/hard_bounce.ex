defmodule Keila.Mailings.MessageActions.HardBounce do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Message

  @doc """
  Runs side-effects associated with receiving a hard bounce for a message.
  """
  @spec handle(Message.id(), map()) :: :ok
  def handle(message_id, data \\ %{}) do
    message_id
    |> maybe_update_message()
    |> tap_if_not_nil(&update_contact(&1))
    |> tap_if_not_nil(&log_event(&1, data))
  end

  defp maybe_update_message(message_id) do
    from(r in Message,
      where: r.id == ^message_id and is_nil(r.hard_bounce_received_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [hard_bounce_received_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  def update_contact(%Message{contact_id: contact_id}) do
    Keila.Contacts.update_contact_status(contact_id, :unreachable)
  end

  defp log_event(%Message{id: message_id, contact_id: contact_id}, data) do
    Keila.Tracking.log_event("hard_bounce", contact_id, message_id, data)
  end
end
