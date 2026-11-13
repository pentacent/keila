defmodule Keila.AuthTest.Events do
  use Keila.DataCase, async: true
  import Ecto.Query
  alias Keila.Auth
  alias Keila.Auth.Event
  alias Keila.Auth.EventPruner

  setup do
    retention_days =
      Application.get_env(:keila, Keila.Auth) |> Keyword.fetch!(:event_retention_days)

    %{user: insert!(:user), retention_days: retention_days}
  end

  @tag :auth_events
  test "log_event/4 stores the event with its IPv4 or IPv6 address", %{user: user} do
    user_id = user.id
    ipv6 = {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}

    {:ok, event} =
      Auth.log_event(:login, user.id, {203, 0, 113, 7}, data: %{"user_agent" => "Peter"})

    assert %Event{type: :login, user_id: ^user_id, ip: {203, 0, 113, 7}} =
             Repo.get(Event, event.id)

    {:ok, event} = Auth.log_event(:login_failed, nil, ipv6)
    assert %Event{ip: ^ipv6, user_id: nil} = Repo.get(Event, event.id)

    {:ok, event} = Auth.log_event(:logout, user.id, nil)
    assert %Event{ip: nil} = Repo.get(Event, event.id)
  end

  @tag :auth_events
  test "prune_events/1 deletes events older than the retention period", %{
    user: user,
    retention_days: retention_days
  } do
    {:ok, old_event} = Auth.log_event(:login, user.id, {127, 0, 0, 1})
    {:ok, recent_event} = Auth.log_event(:login, user.id, {127, 0, 0, 1})
    set_inserted_at(old_event, days_ago(retention_days + 1))
    set_inserted_at(recent_event, days_ago(retention_days - 1))

    assert {1, _} = Auth.prune_events()
    assert Repo.get(Event, recent_event.id)
  end

  @tag :auth_events
  test "EventPruner prunes events in batches and re-enqueues itself", %{
    user: user,
    retention_days: retention_days
  } do
    batch_size = EventPruner.batch_size()
    inserted_at = days_ago(retention_days + 1)

    Repo.insert_all(
      Event,
      for _ <- 1..(batch_size + 1) do
        %{type: :login, user_id: user.id, inserted_at: inserted_at}
      end
    )

    Oban.insert!(EventPruner.new(%{}))
    assert %{success: 2} = Oban.drain_queue(queue: :system, with_recursion: true)

    assert 0 == Repo.aggregate(Event, :count, :id)
  end

  defp set_inserted_at(event, inserted_at) do
    from(e in Event, where: e.id == ^event.id)
    |> Repo.update_all(set: [inserted_at: inserted_at])
  end

  defp days_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-n, :day)
  end
end
