defmodule KeilaWeb.TrackingController do
  use KeilaWeb, :controller
  alias Keila.Tracking

  @spec track_open(Conn.t(), map()) :: Conn.t()
  def track_open(conn, %{
        "encoded_url" => encoded_url,
        "recipient_id" => recipient_id,
        "hmac" => hmac
      }) do
    opts = [user_agent: conn |> get_req_header("user-agent") |> List.first()]

    case Tracking.track_open_and_get_link(encoded_url, recipient_id, hmac, opts) do
      {:ok, url} -> redirect(conn, external: url)
      :error -> put_status(conn, 404) |> halt()
    end
  end

  @spec track_click(Conn.t(), map()) :: Conn.t()
  def track_click(
        conn,
        %{
          "encoded_url" => encoded_url,
          "recipient_id" => recipient_id,
          "hmac" => hmac,
          "link_id" => link_id
        }
      ) do
    opts = [user_agent: conn |> get_req_header("user-agent") |> List.first()]

    case Tracking.track_click_and_get_link(encoded_url, recipient_id, link_id, hmac, opts) do
      {:ok, url} -> redirect(conn, external: url)
      :error -> put_status(conn, 404) |> halt()
    end
  end
end
