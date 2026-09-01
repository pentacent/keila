defmodule Keila.Mailings.Renderer.LiquidCacheTest do
  use ExUnit.Case, async: false
  alias Keila.Mailings.Renderer.LiquidCache

  setup do
    :ets.delete_all_objects(LiquidCache)
    :ok
  end

  test "get/2 runs the fun on a miss, caches the result, and serves hits without re-running" do
    sha256 = sha256()
    self = self()

    assert {:ok, :parsed} = LiquidCache.get(sha256, fn -> {:ok, :parsed} end)
    assert [{^sha256, {:ok, :parsed}, _}] = :ets.lookup(LiquidCache, sha256)

    assert {:ok, :parsed} = LiquidCache.get(sha256, fn -> send(self, :again) && {:ok, :other} end)
    refute_receive :again
  end

  test "get/2 refreshes cache entry timestamp" do
    sha256 = sha256()
    inserted_at = now() - div(LiquidCache.ttl(), 2)
    :ets.insert(LiquidCache, {sha256, :cached, inserted_at})

    assert :cached = LiquidCache.get(sha256, fn -> nil end)

    [{^sha256, _value, retrieved_at}] = :ets.lookup(LiquidCache, sha256)
    assert retrieved_at > inserted_at
  end

  test "get/2 returns function result even when LiquidCache process is down" do
    :ok = Supervisor.terminate_child(Keila.Supervisor, LiquidCache)
    assert :result = LiquidCache.get(sha256(), fn -> :result end)
  after
    {:ok, _pid} = Supervisor.restart_child(Keila.Supervisor, LiquidCache)
  end

  test "evict removes entries older than the TTL" do
    recent = sha256()
    stale = sha256()
    :ets.insert(LiquidCache, {recent, :recent, now()})
    :ets.insert(LiquidCache, {stale, :stale, now() - LiquidCache.ttl() - 1})

    evict()

    assert [{^recent, _, _}] = :ets.lookup(LiquidCache, recent)
    assert [] = :ets.lookup(LiquidCache, stale)
  end

  test "evict enforces entries limit and drops old entries" do
    now = now()

    [oldest | rest] =
      for i <- 0..LiquidCache.max_entries() do
        sha256 = sha256()
        :ets.insert(LiquidCache, {sha256, i, now + i})
        sha256
      end

    evict()

    assert :ets.info(LiquidCache, :size) == LiquidCache.max_entries()
    assert [] = :ets.lookup(LiquidCache, oldest)
    assert Enum.all?(rest, fn sha256 -> :ets.lookup(LiquidCache, sha256) != [] end)
  end

  defp sha256(), do: :crypto.hash(:sha256, "test-#{System.unique_integer([:positive])}")

  defp now(), do: System.monotonic_time(:millisecond)

  defp evict() do
    send(Process.whereis(LiquidCache), :evict)

    # Ensure LiquidCache has processed its message queue
    :sys.get_state(LiquidCache)
  end
end
