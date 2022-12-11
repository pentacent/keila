defmodule KeilaWeb.TrackingControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Tracking
  alias Keila.Tracking.Link

  @url "https://example.com/?query=foo&bar=#foobar"
  @moduletag :tracking_controller

  test "track opens", %{conn: conn} do
    campaign = insert!(:mailings_campaign)
    recipient = insert!(:mailings_recipient, campaign: campaign)

    assert link = %Link{} = Tracking.register_link(@url, campaign.id)
    assert link == Tracking.get_or_register_link(@url, campaign.id)
    assert link.url == @url

    path =
      Tracking.get_tracking_path(conn, :open, %{
        campaign_id: campaign.id,
        recipient_id: recipient.id,
        url: @url
      })

    conn =
      build_conn()
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:107.0) Gecko/20100101 Firefox/107.0"
      )
      |> get(path)

    assert conn.status == 302

    updated_recipient = Keila.Repo.get(Keila.Mailings.Recipient, recipient.id)
    assert not is_nil(updated_recipient.opened_at)
    assert is_nil(updated_recipient.clicked_at)
  end

  test "dont track open if user-agent is considered a bot", %{conn: conn} do
    campaign = insert!(:mailings_campaign)
    recipient = insert!(:mailings_recipient, campaign: campaign)

    assert link = %Link{} = Tracking.register_link(@url, campaign.id)
    assert link == Tracking.get_or_register_link(@url, campaign.id)
    assert link.url == @url

    path =
      Tracking.get_tracking_path(conn, :open, %{
        campaign_id: campaign.id,
        recipient_id: recipient.id,
        url: @url
      })

    conn =
      build_conn()
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246 Mozilla/5.0"
      )
      |> get(path)

    assert conn.status == 302

    updated_recipient = Keila.Repo.get(Keila.Mailings.Recipient, recipient.id)
    assert is_nil(updated_recipient.opened_at)
    assert is_nil(updated_recipient.clicked_at)
  end

  test "track clicks", %{conn: conn} do
    campaign = insert!(:mailings_campaign)
    recipient = insert!(:mailings_recipient, campaign: campaign)

    assert link = %Link{} = Tracking.register_link(@url, campaign.id)
    assert link == Tracking.get_or_register_link(@url, campaign.id)
    assert link.url == @url

    path =
      Tracking.get_tracking_path(conn, :click, %{
        campaign_id: campaign.id,
        recipient_id: recipient.id,
        url: @url
      })

    conn = get(conn, path)
    assert conn.status == 302

    updated_recipient = Keila.Repo.get(Keila.Mailings.Recipient, recipient.id)
    assert not is_nil(updated_recipient.opened_at)
    assert not is_nil(updated_recipient.clicked_at)
  end
end
