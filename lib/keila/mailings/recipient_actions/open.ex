defmodule Keila.Mailings.RecipientActions.Open do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Recipient

  @doc """
  Runs side-effects associated with a recipient opening an email.
  """
  @spec handle(Recipient.id()) :: :ok
  def handle(recipient_id) do
    recipient_id
    |> maybe_update_recipient()
    |> tap_if_not_nil(&log_event/1)
  end

  defp maybe_update_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.opened_at),
      select: struct(r, [:id, :contact_id, :campaign_id]),
      update: [set: [opened_at: fragment("now()")]]
    )
    |> Repo.update_one([])
  end

  defp log_event(%Recipient{id: recipient_id, contact_id: contact_id}) do
    Keila.Tracking.log_event("open", contact_id, recipient_id, %{})
  end
end
