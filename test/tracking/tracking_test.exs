defmodule Keila.TrackingTest do
  use Keila.DataCase
  alias Keila.Tracking
  alias Keila.Tracking.{Link, Event}

  @url "https://example.com/?query=foo&bar=#foobar"
  @moduletag :tracking

  test "register links" do
    campaign = insert!(:mailings_campaign)
    assert link = %Link{} = Tracking.register_link(@url, campaign.id)
    assert link == Tracking.get_or_register_link(@url, campaign.id)
    assert link.url == @url
  end

  test "Log contact events" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    %{id: contact_id} = insert!(:contact, project_id: project.id)
    assert {:ok, _} = Tracking.log_event("open", contact_id, %{})
    assert {:ok, _} = Tracking.log_event("click", contact_id, %{})
    assert {:ok, _} = Tracking.log_event("unsubscribe", contact_id, %{})

    events = Tracking.get_contact_events(contact_id)

    assert Enum.count(events) == 3

    assert Enum.find(
             events,
             &match?(%Event{type: :unsubscribe, contact_id: ^contact_id, data: %{}}, &1)
           )

    assert Enum.find(
             events,
             &match?(%Event{type: :click, contact_id: ^contact_id, data: %{}}, &1)
           )

    assert Enum.find(
             events,
             &match?(%Event{type: :open, contact_id: ^contact_id, data: %{}}, &1)
           )
  end
end
