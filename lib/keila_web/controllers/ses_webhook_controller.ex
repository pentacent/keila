defmodule KeilaWeb.SESWebhookController do
  use KeilaWeb, :controller
  use Keila.Repo
  require Logger
  alias Keila.Mailings
  alias Keila.Mailings.Message

  plug Plug.Parsers,
    parsers: [{KeilaWeb.PlainTextJSONParser, json_decoder: Jason}]

  plug :authorize
  plug :put_resource

  @spec webhook(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def webhook(conn = %{assigns: %{ses_message: %{"bounce" => %{"bounceType" => "Permanent"}}}}, _) do
    bounce_subtype = get_in(conn.assigns.ses_message, ["bounce", "bounceSubType"])
    data = %{"type" => "ses", "ses_bounce_subtype" => bounce_subtype}
    Mailings.handle_message_hard_bounce(conn.assigns.message.id, data)

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{assigns: %{ses_message: %{"bounce" => %{"bounceType" => "Transient"}}}}, _) do
    bounce_subtype = get_in(conn.assigns.ses_message, ["bounce", "bounceSubType"])
    data = %{"type" => "ses", "ses_bounce_subtype" => bounce_subtype}
    Mailings.handle_message_soft_bounce(conn.assigns.message.id, data)

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{assigns: %{ses_message: %{"complaint" => %{}}}}, _) do
    Mailings.handle_message_complaint(conn.assigns.message.id, %{})

    conn |> send_resp(200, "")
  end

  def webhook(conn = %{body_params: %{"Type" => "SubscriptionConfirmation"}}, _) do
    HTTPoison.get!(conn.body_params["SubscribeURL"])
    Logger.info("Subscribed to SNS topic #{conn.body_params["TopicArn"]}")

    conn |> send_resp(200, "")
  end

  def webhook(conn, _) do
    Logger.info("Unhandled SES Webhook: #{inspect(conn.body_params)}")

    conn |> send_resp(204, "")
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
        with {:ok, raw_ses_message} = Map.fetch(conn.body_params, "Message"),
             {:ok, ses_message} <- Jason.decode(raw_ses_message),
             ses_message_id when is_binary(ses_message_id) <-
               get_in(ses_message, ["mail", "messageId"]),
             message = %Message{} <- Repo.get_by(Message, receipt: ses_message_id) do
          conn
          |> assign(:ses_message, ses_message)
          |> assign(:message, message)
        else
          _ ->
            conn |> send_resp(404, "") |> halt()
        end
    end
  end
end
