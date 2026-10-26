defmodule Keila.Mailings.SwooshAdapters.Cloudflare do
  @moduledoc """
  A Swoosh adapter for the Cloudflare Email Service REST API.

  Cloudflare's only SMTP submission endpoint is implicit TLS on port 465, which
  many hosts block for outbound traffic. The REST API is plain HTTPS, so this
  adapter is usable from anywhere.

  It also acts on the per-recipient outcome that Cloudflare already reports:
  when the recipient shows up in `permanent_bounces` or `suppressed_recipients`,
  the adapter returns `{:error, :invalid_email}`, which is what
  `Keila.Mailings.DeliveryWorker` turns into an unreachable contact.

  Configuration (see `Keila.Mailings.SenderAdapters.Cloudflare`):

      adapter: Keila.Mailings.SwooshAdapters.Cloudflare,
      account_id: "023e105f4ecef8ad9ca31a8372d0c353",
      api_token: "..."

  The `from` address must belong to a sending domain that has been onboarded
  for Email Sending in the Cloudflare account. Attachments are not supported by
  this adapter yet; Keila campaigns do not use them.
  """

  use Swoosh.Adapter, required_config: [:account_id, :api_token]

  require Logger

  @base_url "https://api.cloudflare.com/client/v4"

  # Headers Cloudflare accepts in the `headers` field, besides any `X-` header.
  # A header outside this list makes Cloudflare reject the whole request, so the
  # adapter drops anything else (logging it) instead of losing the message.
  # https://developers.cloudflare.com/email-service/reference/headers/
  @allowed_headers ~w(
    in-reply-to references thread-index thread-topic
    list-unsubscribe list-unsubscribe-post list-id list-archive list-help
    list-owner list-post list-subscribe precedence auto-submitted
    content-language keywords comments importance priority sensitivity
    organization require-recipient-valid-since expires reply-by archived-at
  )

  @impl true
  def deliver(%Swoosh.Email{} = email, config) do
    account_id = Keyword.fetch!(config, :account_id)
    api_token = Keyword.fetch!(config, :api_token)

    url = "#{@base_url}/accounts/#{account_id}/email/sending/send"

    headers = [
      {"Authorization", "Bearer #{api_token}"},
      {"Content-Type", "application/json"}
    ]

    body = email |> prepare_body() |> Swoosh.json_library().encode!()

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, status, _headers, response} when status in 200..299 ->
        handle_success(response, email)

      {:ok, status, _headers, response} ->
        {:error, {status, decode_or_raw(response)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_success(response, email) do
    case decode_or_raw(response) do
      %{"success" => true, "result" => result} ->
        receipt =
          Map.take(result, [
            "message_id",
            "delivered",
            "queued",
            "permanent_bounces",
            "suppressed_recipients"
          ])

        if recipient_rejected?(email, receipt) do
          {:error, :invalid_email}
        else
          {:ok, %{id: receipt["message_id"]}}
        end

      %{"success" => false, "errors" => errors} ->
        {:error, {200, errors}}

      other ->
        {:error, {200, other}}
    end
  end

  # Cloudflare reports the recipient outcome per address rather than as an HTTP
  # error, and Keila sends one recipient per message, so either list means this
  # contact is not deliverable.
  defp recipient_rejected?(email, receipt) do
    rejected =
      Map.get(receipt, "permanent_bounces", []) ++
        Map.get(receipt, "suppressed_recipients", [])

    case recipients(email.to) do
      [recipient] ->
        if recipient in rejected do
          Logger.warning("Cloudflare Email Service rejected #{recipient}")

          true
        else
          false
        end

      _ ->
        false
    end
  end

  defp prepare_body(email) do
    %{
      "from" => address(email.from),
      "to" => recipient_field(email.to),
      "subject" => email.subject,
      "text" => email.text_body,
      "html" => email.html_body
    }
    |> put_if_present("cc", recipient_field(email.cc))
    |> put_if_present("bcc", recipient_field(email.bcc))
    |> put_if_present("reply_to", reply_to(email.reply_to))
    |> put_if_present("headers", headers(email.headers))
  end

  defp reply_to(nil), do: nil
  defp reply_to([]), do: nil
  defp reply_to([single | _]), do: address(single)
  defp reply_to(single), do: address(single)

  defp headers(headers) when map_size(headers) == 0, do: nil

  defp headers(headers) do
    headers
    |> Enum.flat_map(fn {name, value} ->
      key = String.downcase(name)

      cond do
        String.starts_with?(key, "x-") ->
          [{name, value}]

        key == "precedence" ->
          # Cloudflare accepts only lowercase `bulk`, `list` or `junk`.
          [{name, String.downcase(value)}]

        key in @allowed_headers ->
          [{name, value}]

        true ->
          Logger.warning(
            "Cloudflare adapter: dropping header #{name}, which Email Service does not accept"
          )

          []
      end
    end)
    |> Map.new()
    |> case do
      empty when map_size(empty) == 0 -> nil
      kept -> kept
    end
  end

  defp put_if_present(body, _key, nil), do: body
  defp put_if_present(body, _key, []), do: body
  defp put_if_present(body, _key, map) when is_map(map) and map_size(map) == 0, do: body
  defp put_if_present(body, key, value), do: Map.put(body, key, value)

  defp recipient_field([]), do: nil
  defp recipient_field([single]), do: address(single)
  defp recipient_field(recipients), do: Enum.map(recipients, &address/1)

  defp recipients(recipients), do: Enum.map(recipients, &address/1)

  # Swoosh keeps a single sender as a {name, address} tuple and recipients as
  # lists of those tuples.
  defp address({_name, address}), do: address
  defp address(address) when is_binary(address), do: address

  defp decode_or_raw(raw) do
    case Swoosh.json_library().decode(raw) do
      {:ok, decoded} -> decoded
      {:error, _} -> raw
    end
  end
end
