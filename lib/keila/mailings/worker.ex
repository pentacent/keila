defmodule Keila.Mailings.Worker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  alias Keila.Mailings
  alias Keila.Mailings.{Recipient, Builder}

  @impl true
  def perform(%Oban.Job{args: %{"recipient_id" => recipient_id}}) do
    recipient =
      from(r in Recipient,
        where: r.id == ^recipient_id,
        preload: [contact: [], campaign: [[sender: [:shared_sender]], :template]]
      )
      |> Repo.one()

    if recipient.contact.status == :active do
      recipient.campaign
      |> Builder.build(recipient, %{})
      |> tap(&ensure_valid!/1)
      |> Keila.Mailer.deliver_with_sender(recipient.campaign.sender)
      |> maybe_update_recipient(recipient)
    else
      from(r in Recipient, where: r.id == ^recipient.id) |> Repo.delete_all()

      :ok
    end
  end

  defp ensure_valid!(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      raise "Invalid email"
    end
  end

  defp maybe_update_recipient({:ok, receipt}, recipient) do
    update_recipient(recipient, receipt)
  end

  defp maybe_update_recipient(_, _) do
    :ok
  end

  defp update_recipient(recipient, receipt) do
    receipt = get_receipt(receipt)

    from(r in Recipient,
      where: r.id == ^recipient.id,
      update: [set: [sent_at: fragment("NOW()"), receipt: ^receipt]]
    )
    |> Repo.update_all([])

    :ok
  end

  defp get_receipt(%{id: receipt}), do: receipt
  defp get_receipt(receipt) when is_binary(receipt), do: receipt
  defp get_receipt(_), do: nil
end
