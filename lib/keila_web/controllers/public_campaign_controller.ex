defmodule KeilaWeb.PublicCampaignController do
  use KeilaWeb, :controller

  plug :fetch_campaign

  @archive_csp "sandbox allow-popups allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation; frame-ancestors *"

  def show(conn, _params) do
    case Keila.Mailings.CampaignRenderer.render_preview(conn.assigns.campaign) do
      %{valid?: true, html_body: html} when is_binary(html) ->
        conn
        |> put_resp_header("content-security-policy", @archive_csp)
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      %{valid?: true, text_body: text} when is_binary(text) ->
        conn |> put_resp_content_type("text/plain") |> send_resp(200, text)

      _ ->
        raise KeilaWeb.NotFoundError
    end
  end

  defp fetch_campaign(conn, _) do
    id = conn.params["id"]

    case Keila.Mailings.get_public_campaign(id) do
      nil -> raise KeilaWeb.NotFoundError
      campaign -> assign(conn, :campaign, campaign)
    end
  end
end
