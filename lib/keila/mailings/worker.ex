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

    recipient = load_recipient(recipient_id)

    with :ok <- check_sender_rate_limit(recipient),
         :ok <- ensure_valid_recipient(recipient),
         email <- Builder.build(recipient.campaign, recipient, %{}),
         :ok <- ensure_valid_email(email) do
      Keila.Mailer.deliver_with_sender(email, recipient.campaign.sender)
    end
    |> handle_result(recipient)
  end

  defp load_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id,
      preload: [contact: [], campaign: [[sender: [:shared_sender]], :template]]
    )
    |> Repo.one()
  end

  defp ensure_valid_recipient(%{contact: %{status: :active, email: email}, sent_at: nil})
       when not is_nil(email),
       do: :ok

  defp ensure_valid_recipient(%{sent_at: sent_at}) when not is_nil(sent_at),
    do: {:error, :already_sent}

  defp ensure_valid_recipient(_recipient), do: {:error, :invalid_contact}

  defp check_sender_rate_limit(recipient) do
    case Keila.Mailer.check_sender_rate_limit(recipient.campaign.sender) do
      :ok ->
        :ok

      {:error, min_delay} ->
        # wait until the minimum delay + add randomness to even out load
        random_delay = :rand.uniform(60)
        delay = min_delay + :rand.uniform(60)

        Logger.debug(
          "Snoozing email to #{recipient.contact.email} for campaign #{recipient.campaign.id} for #{min_delay} + #{random_delay} s"
        )

        {:snooze, delay}
    end
  end

  defp ensure_valid_email(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      {:error, :invalid_email}
    else
      :ok
    end
  end

  # Email was sent successfully
  defp handle_result({:ok, raw_receipt}, recipient) do
    receipt = get_receipt(raw_receipt)

    from(r in Recipient,
      where: r.id == ^recipient.id,
      update: [set: [sent_at: fragment("NOW()"), receipt: ^receipt]]
    )
    |> Repo.update_all([])

    :ok
  end

  # Sending needs to be retried later
  defp handle_result({:snooze, delay}, _), do: {:snooze, delay}

  # Email was already sent
  defp handle_result({:error, :already_sent}, _), do: {:cancel, :already_sent}

  # Another error occurred. Sending is not retried.
  defp handle_result({:error, reason}, recipient) do
    Logger.warning(
      "Failed sending email to #{recipient.contact.email} for campaign #{recipient.campaign.id}: #{inspect(reason)}"
    )

    from(r in Recipient,
      where: r.id == ^recipient.id,
      update: [set: [failed_at: fragment("NOW()")]]
    )
    |> Repo.update_all([])

    {:cancel, reason}
  end

  defp get_receipt(%{id: receipt}), do: receipt
  defp get_receipt(receipt) when is_binary(receipt), do: receipt
  defp get_receipt(_), do: nil
end
