defmodule Keila.Mailings.RecipientActions.SoftBounce do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Recipient

  @doc """
  Runs side-effects associated with receiving a soft bounce from a recipient.
  """
  @spec handle(Recipient.id(), map()) :: :ok
  def handle(recipient_id, data \\ %{}) do
    recipient_id
    |> maybe_update_recipient()
    |> tap_if_not_nil(&maybe_update_contact(&1))
    |> tap_if_not_nil(&log_event(&1, data))
  end

  defp maybe_update_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.soft_bounce_received_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [soft_bounce_received_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  defp maybe_update_contact(%{contact_id: contact_id}) do
    recent_soft_bounces =
      from(r in Recipient,
        where: r.contact_id == ^contact_id and not is_nil(r.sent_at),
        order_by: r.sent_at,
        limit: 5
      )
      |> Repo.aggregate(:count, :id)

    if recent_soft_bounces >= 3 do
      Keila.Contacts.update_contact_status(contact_id, :unreachable)
    end
  end

  defp log_event(%Recipient{id: recipient_id, contact_id: contact_id}, data) do
    Keila.Tracking.log_event("soft_bounce", contact_id, recipient_id, data)
  end
end
