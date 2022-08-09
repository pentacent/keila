defmodule Keila.Mailings.Worker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  alias Keila.Mailings.{Recipient, Builder, Sender}
  require ExRated

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"recipient_id" => recipient_id, "recipient_count" => recipient_count} = args

    recipient =
      from(r in Recipient,
        where: r.id == ^recipient_id,
        preload: [contact: [], campaign: [[sender: [:shared_sender]], :template]]
      )
      |> Repo.one()

    sender = recipient.campaign.sender

    case Sender.check_rate(sender) do
      {:error, _} ->
        # wait is proportional to the number of workers
        {:snooze, 1 * recipient_count}

      {:ok, _} ->
        if recipient.contact.status == :active && recipient.campaign.sender do
          recipient.campaign
          |> Builder.build(recipient, %{})
          |> tap(&ensure_valid!/1)
          |> Keila.Mailer.deliver_with_sender(sender)
          |> maybe_update_recipient(recipient)
        else
          from(r in Recipient, where: r.id == ^recipient.id) |> Repo.delete_all()

          :ok
        end
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
