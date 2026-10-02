defmodule KeilaWeb.MailgunWebhookController do
  use KeilaWeb, :controller
  use Keila.Repo
  require Logger
  alias Keila.Mailings
  alias Keila.Mailings.Message
  alias Keila.Mailings.SenderAdapters.Mailgun

  plug :put_resource
  plug :authorize

  @moduledoc """
  Receives webhooks from Mailgun to process bounces and complaints.

  Webhooks are verified with the *HTTP webhook signing key* configured for the
  sender that sent the message the event relates to.
  """

  @spec webhook(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def webhook(
        conn = %{assigns: %{event_data: %{"event" => "failed", "severity" => "permanent"}}},
        _
      ) do
    Mailings.handle_message_hard_bounce(conn.assigns.message.id, event_log_data(conn))

    conn |> send_resp(200, "")
  end

  def webhook(
        conn = %{assigns: %{event_data: %{"event" => "failed", "severity" => "temporary"}}},
        _
      ) do
    Mailings.handle_message_soft_bounce(conn.assigns.message.id, event_log_data(conn))

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{assigns: %{event_data: %{"event" => "complained"}}}, _) do
    Mailings.handle_message_complaint(conn.assigns.message.id, %{})

    conn |> send_resp(200, "")
  end

  def webhook(conn, _) do
    conn |> send_resp(204, "")
  end

  defp event_log_data(conn) do
    event_data = conn.assigns.event_data

    %{
      "type" => "mailgun",
      "mailgun_reason" => event_data["reason"],
      "mailgun_code" => get_in(event_data, ["delivery-status", "code"])
    }
  end

  defp put_resource(conn, _opts) do
    with event_data = %{} <- conn.body_params["event-data"],
         mailgun_message_id when is_binary(mailgun_message_id) <-
           get_in(event_data, ["message", "headers", "message-id"]),
         message = %Message{} <- get_message(mailgun_message_id),
         sender = %{} <- Mailings.get_sender(message.sender_id) do
      conn
      |> assign(:event_data, event_data)
      |> assign(:message, message)
      |> assign(:sender, sender)
    else
      _ ->
        # Mailgun retries delivery for any status code other than 406. Events
        # for messages Keila doesn't know about (e.g. mail sent through the same
        # Mailgun domain by another application) should not be retried.
        conn |> send_resp(406, "") |> halt()
    end
  end

  defp authorize(conn, _opts) do
    with %{type: "mailgun", mailgun_webhook_signing_key: signing_key} <-
           conn.assigns.sender.config,
         true <- Mailgun.valid_signature?(signing_key, conn.body_params["signature"]) do
      conn
    else
      _ -> conn |> send_resp(403, "") |> halt()
    end
  end

  # Swoosh stores the ID returned by the Mailgun API as receipt, which is
  # enclosed in angle brackets (`<123@example.com>`). The `message-id` header in
  # webhook payloads doesn't contain the angle brackets.
  defp get_message(mailgun_message_id) do
    id = String.trim(mailgun_message_id, "<") |> String.trim(">")

    from(m in Message, where: m.receipt in ^[id, "<#{id}>"], limit: 1)
    |> Repo.one()
  end
end
