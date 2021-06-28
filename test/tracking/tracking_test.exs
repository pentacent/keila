defmodule Keila.TrackingTest do
  use Keila.DataCase
  alias Keila.Tracking
  alias Keila.Tracking.Link

  @url "https://example.com/?query=foo&bar=#foobar"
  @moduletag :tracking

  test "register links" do
    campaign = insert!(:mailings_campaign)
    assert link = %Link{} = Tracking.register_link(@url, campaign.id)
    assert link == Tracking.get_or_register_link(@url, campaign.id)
    assert link.url == @url
  end
end
