defmodule KeilaWeb.TrackingController do
  use KeilaWeb, :controller

  @spec track_open(Conn.t(), map()) :: Conn.t()
  def track_open(conn, %{
        "encoded_url" => encoded_url,
        "recipient_id" => recipient_id,
        "hmac" => hmac
      }) do
    case Keila.Tracking.track(:open, %{
           encoded_url: encoded_url,
           recipient_id: recipient_id,
           hmac: hmac,
           user_agent: get_req_header(conn, "user-agent")
         }) do
      {:ok, url} -> redirect(conn, external: url)
      :error -> put_status(conn, 404) |> halt()
    end
  end

  @spec track_click(Conn.t(), map()) :: Conn.t()
  def track_click(
        conn,
        params = %{"encoded_url" => encoded_url, "recipient_id" => recipient_id, "hmac" => hmac}
      ) do
    link_id = Map.get(params, "link_id")

    case Keila.Tracking.track(:click, %{
           encoded_url: encoded_url,
           recipient_id: recipient_id,
           link_id: link_id,
           hmac: hmac
         }) do
      {:ok, url} -> redirect(conn, external: url)
      :error -> put_status(conn, 404) |> halt()
    end
  end
end
