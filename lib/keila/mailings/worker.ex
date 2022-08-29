defmodule Keila.Mailings.Worker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  alias Keila.Mailings.{Recipient, Builder}
  require ExRated
  require Logger

  @impl true
  def perform(%Oban.Job{args: args}) do
    # TODO: recipient_count is currently not used but could be used to improve
    # the algorithm snoozing delivery when running for the first time.
    # This would also require check_sender_rate/1 to return information about
    # active rate limits (bucket sizes and scales).
    %{"recipient_id" => recipient_id, "recipient_count" => _recipient_count} = args

    recipient =
      from(r in Recipient,
        where: r.id == ^recipient_id,
        preload: [contact: [], campaign: [[sender: [:shared_sender]], :template]]
      )
      |> Repo.one()

    sender = recipient.campaign.sender

    case Keila.Mailer.check_sender_rate_limit(sender) do
      {:error, min_delay} ->
        # wait until the minimum delay + add randomness to even out load
        random_delay = :rand.uniform(60)
        delay = min_delay + :rand.uniform(60)

        Logger.debug(
          "Snoozing email to #{recipient.contact.email} for campaign #{recipient.campaign.id} for #{min_delay} + #{random_delay} s"
        )

        {:snooze, delay}

      :ok ->
        if recipient.contact.status == :active && recipient.campaign.sender do
          Logger.debug(
            "Sending email to #{recipient.contact.email} for campaign #{recipient.campaign.id}"
          )

          recipient.campaign
          |> Builder.build(recipient, %{})
          |> tap(&ensure_valid!/1)
          |> Keila.Mailer.deliver_with_sender(sender)
          |> maybe_update_recipient(recipient)
        else
          Logger.debug(
            "Skipping sending email to #{recipient.contact.email} for campaign #{recipient.campaign.id}"
          )

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
