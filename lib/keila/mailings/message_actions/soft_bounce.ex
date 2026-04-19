defmodule Keila.Mailings.MessageActions.SoftBounce do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Message

  @doc """
  Runs side-effects associated with receiving a soft bounce for a message.
  """
  @spec handle(Message.id(), map()) :: :ok
  def handle(message_id, data \\ %{}) do
    message_id
    |> maybe_update_message()
    |> tap_if_not_nil(&maybe_update_contact(&1))
    |> tap_if_not_nil(&log_event(&1, data))

    :ok
  end

  defp maybe_update_message(message_id) do
    from(r in Message,
      where: r.id == ^message_id and is_nil(r.soft_bounce_received_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [soft_bounce_received_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  defp maybe_update_contact(%{contact_id: nil}), do: :ok

  defp maybe_update_contact(%{contact_id: contact_id}) do
    recent_soft_bounces =
      from(r in Message,
        where: r.contact_id == ^contact_id and not is_nil(r.sent_at),
        order_by: [desc: r.sent_at],
        limit: 5,
        select: not is_nil(r.soft_bounce_received_at)
      )
      |> Repo.all()
      |> Enum.filter(& &1)
      |> Enum.count()

    if recent_soft_bounces >= 3 do
      Keila.Contacts.update_contact_status(contact_id, :unreachable)
    end
  end

  defp log_event(%Message{contact_id: nil}, _data), do: :ok

  defp log_event(%Message{id: message_id, contact_id: contact_id}, data) do
    Keila.Tracking.log_event("soft_bounce", contact_id, message_id, data)
  end
end
