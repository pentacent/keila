defmodule KeilaWeb.PublicCampaignController do
  use KeilaWeb, :controller

  plug :fetch_campaign

  def show(conn, _params) do
    case Keila.Mailings.CampaignRenderer.render_preview(conn.assigns.campaign) do
      %{valid?: true, html_body: html} when is_binary(html) ->
        conn |> put_resp_content_type("text/html") |> send_resp(200, html)

      %{valid?: true, text_body: text} when is_binary(text) ->
        conn |> put_resp_content_type("text/plain") |> send_resp(200, text)

      _ ->
        conn |> send_resp(404, "") |> halt()
    end
  end

  defp fetch_campaign(conn, _) do
    id = conn.params["id"]

    case Keila.Mailings.get_public_campaign(id) do
      nil -> conn |> send_resp(404, "") |> halt()
      campaign -> assign(conn, :campaign, campaign)
    end
  end
end
