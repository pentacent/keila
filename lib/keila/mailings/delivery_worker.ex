defmodule Keila.Mailings.DeliveryWorker do
  use Oban.Worker,
    queue: :mailer,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing],
      fields: [:args],
      keys: [:message_id]
    ]

  use Keila.Repo
  require Logger
  import Ecto.Query
  alias Keila.Contacts.Contact
  alias Keila.Mailings.Message

  @impl true
  def perform(%Oban.Job{args: %{"message_id" => id}}) do
    message =
      from(m in Message,
        where: m.id == ^id and m.status == :queued,
        preload: [sender: :shared_sender]
      )
      |> Keila.Repo.one()

    with :ok <- ensure_message(message),
         :ok <- ensure_sender(message.sender),
         {:ok, email} <- email_from_message(message) do
      Keila.Mailer.deliver_with_sender(email, message.sender)
    end
    |> then(fn result -> handle_result(result, message) end)
  rescue
    e ->
      set_message_failed(%Message{id: id})

      Logger.error(
        "DeliveryWorker: Unhandled exception for message #{id}: #{Exception.message(e)}"
      )

      {:cancel, :exception}
  end

  defp ensure_message(%Message{}), do: :ok
  defp ensure_message(_), do: {:error, :not_found}

  defp ensure_sender(%Keila.Mailings.Sender{}), do: :ok
  defp ensure_sender(_), do: {:error, :no_sender}

  defp email_from_message(message) do
    Swoosh.Email.new()
    |> Swoosh.Email.to({message.recipient_name, message.recipient_email})
    |> Swoosh.Email.subject(message.subject)
    |> Swoosh.Email.text_body(message.text_body)
    |> Swoosh.Email.html_body(message.html_body)
    |> then(fn email -> {:ok, email} end)
  rescue
    _e in ArgumentError ->
      {:error, :invalid_contact}
  end

  # Email was sent successfully
  defp handle_result({:ok, raw_receipt}, message) do
    receipt = get_receipt(raw_receipt)
    set_message_sent(message, receipt)

    :ok
  end

  # Invalid contact (e.g. unsubscribed or deleted)
  defp handle_result({:error, :invalid_contact}, message) do
    Repo.transaction(fn ->
      message
      |> tap(&set_message_failed/1)
      |> tap(&maybe_set_contact_unreachable/1)
    end)

    {:cancel, :invalid_contact}
  end

  # Invalid email address (returned by Keila.Mailer)
  defp handle_result({:error, :invalid_email}, message) do
    Repo.transaction(fn ->
      message
      |> tap(&set_message_failed/1)
      |> tap(&maybe_set_contact_unreachable/1)
    end)

    {:cancel, :invalid_email}
  end

  # Message not found (e.g. deleted or already processed)
  defp handle_result({:error, :not_found}, nil), do: {:cancel, :not_found}

  # Sender not found
  defp handle_result({:error, :no_sender}, nil), do: {:cancel, :no_sender}

  # Another error occurred. Sending is not retried.
  defp handle_result({:error, reason}, message) do
    Logger.warning(
      "DeliveryWorker: Failed sending email to #{message.recipient_email} for campaign #{message.campaign_id}: #{inspect(reason)}"
    )

    set_message_failed(message)

    {:cancel, reason}
  end

  defp set_message_sent(message, receipt) do
    from(m in Message,
      where: m.id == ^message.id,
      update: [
        set: [
          sent_at: fragment("NOW()"),
          status: :sent,
          receipt: ^receipt,
          updated_at: fragment("NOW()")
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp set_message_failed(message) do
    from(m in Message,
      where: m.id == ^message.id,
      update: [
        set: [
          status: :failed,
          failed_at: fragment("NOW()"),
          updated_at: fragment("NOW()")
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp maybe_set_contact_unreachable(%{contact_id: contact_id}) when not is_nil(contact_id) do
    from(c in Contact,
      where: c.id == ^contact_id,
      update: [
        set: [
          status: :unreachable,
          updated_at: fragment("NOW()")
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp maybe_set_contact_unreachable(_other), do: :ok

  defp get_receipt(%{id: receipt}), do: receipt
  defp get_receipt(receipt) when is_binary(receipt), do: receipt
  defp get_receipt(_), do: nil
end
