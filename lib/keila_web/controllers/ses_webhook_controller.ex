defmodule KeilaWeb.SESWebhookController do
  use KeilaWeb, :controller
  use Keila.Repo
  require Logger

  alias Keila.Mailings.Recipient

  plug Plug.Parsers,
    parsers: [{KeilaWeb.PlainTextJSONParser, json_decoder: Jason}]

  plug :authorize
  plug :put_resource

  @spec webhook(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def webhook(conn = %{assigns: %{message: %{"bounce" => %{"bounceType" => "Permanent"}}}}, _) do
    bounce_subtype = get_in(conn.assigns.message, ["bounce", "bounceSubType"])

    Keila.Contacts.log_event(conn.assigns.recipient.contact_id, "hard_bounce", %{
      "type" => "ses",
      "ses_bounce_subtype" => bounce_subtype
    })

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{assigns: %{message: %{"bounce" => %{"bounceType" => "Transient"}}}}, _) do
    bounce_subtype = get_in(conn.assigns.message, ["bounce", "bounceSubType"])

    Keila.Contacts.log_event(conn.assigns.recipient.contact_id, "soft_bounce", %{
      "type" => "ses",
      "ses_bounce_subtype" => bounce_subtype
    })

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{assigns: %{message: %{"complaint" => %{}}}}, _) do
    Keila.Contacts.log_event(conn.assigns.recipient.contact_id, "complaint")

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{body_params: %{"Type" => "SubscriptionConfirmation"}}, _) do
    HTTPoison.get!(conn.body_params["SubscribeURL"])
    Logger.info("Subscribed to SNS topic #{conn.body_params["TopicArn"]}")

    conn |> send_resp(200, "")
  end

  def webhook(conn, _) do
    Logger.info("Unhandled SES Webhook: #{inspect(conn.body_params)}")
  end

  defp authorize(conn, _opts) do
    if Keila.Mailings.SenderAdapters.SES.valid_signature?(conn.body_params) do
      conn
    else
      conn |> send_resp(403, "") |> halt()
    end
  end

  defp put_resource(conn, _opts) do
    params = conn.body_params

    case params["Type"] do
      "SubscriptionConfirmation" ->
        conn

      "Notification" ->
        with {:ok, raw_message} = Map.fetch(conn.body_params, "Message"),
             {:ok, message} <- Jason.decode(raw_message),
             message_id when is_binary(message_id) <- get_in(message, ["mail", "messageId"]),
             recipient = %Recipient{} <- Repo.get_by(Recipient, receipt: message_id) do
          conn
          |> assign(:message, message)
          |> assign(:recipient, recipient)
        else
          _ ->
            conn |> send_resp(404, "") |> halt()
        end
    end
  end
end
