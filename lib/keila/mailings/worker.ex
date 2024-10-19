defmodule Keila.Mailings.Worker do
  @moduledoc """
  This worker builds and delivers queued emails.
  """

  use Oban.Worker,
    queue: :mailer,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing],
      fields: [:args],
      keys: [:recipient_id]
    ]

  use Keila.Repo
  alias Keila.Mailings.{Recipient, Builder, RateLimiter}
  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"recipient_id" => recipient_id}} = job) do
    recipient = load_recipient(recipient_id)

    with :ok <- check_sender_rate_limit(recipient, job),
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

  defp check_sender_rate_limit(recipient, job) do
    scheduling_requested_at = scheduling_requested_at(job)

    case RateLimiter.check_sender_rate_limit(recipient.campaign.sender, scheduling_requested_at) do
      :ok ->
        :ok

      {:error, {schedule_at, scheduling_requested_at}} ->
        job.args
        |> Map.put("scheduling_requested_at", scheduling_requested_at)
        |> __MODULE__.new(replace: [executing: [:args]])
        |> Oban.insert!()

        delay = DateTime.diff(schedule_at, scheduling_requested_at)

        Logger.debug(
          "Snoozing email to #{recipient.contact.email} for campaign #{recipient.campaign.id} for #{delay}s."
        )

        {:snooze, delay}
    end
  end

  defp scheduling_requested_at(%{args: %{"scheduling_requested_at" => scheduling_requested_at}})
       when is_binary(scheduling_requested_at) do
    case DateTime.from_iso8601(scheduling_requested_at) do
      {:ok, scheduling_requested_at, 0} -> scheduling_requested_at
      _other -> nil
    end
  end

  defp scheduling_requested_at(_job), do: nil

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
