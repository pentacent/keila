defmodule KeilaWeb.PublicCampaignController do
  use KeilaWeb, :controller

  plug :fetch_campaign

  def show(conn, _params) do
    email = Keila.Mailings.Builder.build_preview(conn.assigns.campaign, %{})

    cond do
      Map.has_key?(email.headers, "X-Keila-Invalid") ->
        conn |> send_resp(404, "") |> halt()

      email.html_body ->
        conn |> put_resp_content_type("text/html") |> send_resp(200, email.html_body)

      email.text_body ->
        conn |> put_resp_content_type("text/plain") |> send_resp(200, email.text_body)

      true ->
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
