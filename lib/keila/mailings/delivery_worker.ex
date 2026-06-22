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
  alias Keila.EmailAddress
  alias Keila.EmailHeader
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
    |> put_cc(message.cc)
    |> put_bcc(message.bcc)
    |> put_headers(message)
    |> then(fn email -> {:ok, email} end)
  rescue
    _e in ArgumentError ->
      {:error, :invalid_contact}
  end

  defp put_cc(email, addresses) do
    case EmailAddress.to_swoosh_recipients(addresses) do
      {:ok, recipients} -> Swoosh.Email.cc(email, recipients)
      :error -> email
    end
  end

  defp put_bcc(email, addresses) do
    case EmailAddress.to_swoosh_recipients(addresses) do
      {:ok, recipients} -> Swoosh.Email.bcc(email, recipients)
      :error -> email
    end
  end

  defp put_headers(email, message) do
    email
    |> put_custom_headers(message)
    |> maybe_put_list_unsubscribe(message)
    |> maybe_put_list_unsubscribe_post()
    |> maybe_put_bulk_header(message)
  end

  defp put_custom_headers(email, message) do
    Enum.reduce(message.headers || %{}, email, fn {name, value}, acc ->
      case EmailHeader.validate(name, value) do
        :ok ->
          Swoosh.Email.header(acc, name, value)

        {:error, reason} ->
          Logger.warning("Dropping invalid custom header on message #{message.id}: #{reason}")
          acc
      end
    end)
  end

  # TODO: When automations are implemented, this function should also return true for
  # messages from automations
  defp maybe_put_list_unsubscribe(email, message) do
    requires_unsubscribe_header? =
      not is_nil(message.contact_id) and
        not (is_nil(message.campaign_id) and
               is_nil(message.form_id) and
               is_nil(message.form_params_id))

    if requires_unsubscribe_header? and not has_header?(email, "List-Unsubscribe") do
      value = "<#{Keila.Mailings.get_unsubscribe_link(message.project_id, message.id)}>"
      Swoosh.Email.header(email, "List-Unsubscribe", value)
    else
      email
    end
  end

  defp maybe_put_list_unsubscribe_post(email) do
    https? = match?("<https://" <> _, get_header(email, "List-Unsubscribe"))

    if https? and not has_header?(email, "List-Unsubscribe-Post") do
      Swoosh.Email.header(email, "List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    else
      email
    end
  end

  defp maybe_put_bulk_header(email, %{campaign_id: campaign_id}) when not is_nil(campaign_id) do
    if Application.get_env(:keila, Keila.Mailings)[:enable_precedence_header] do
      Swoosh.Email.header(email, "Precedence", "Bulk")
    else
      email
    end
  end

  defp maybe_put_bulk_header(email, _message), do: email

  defp has_header?(email, key) do
    key = String.downcase(key)
    Enum.any?(email.headers, fn {existing, _value} -> String.downcase(existing) == key end)
  end

  defp get_header(email, key) do
    key = String.downcase(key)

    Enum.find_value(email.headers, fn {existing, value} ->
      if String.downcase(existing) == key, do: value
    end)
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
