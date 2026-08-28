defmodule Keila.Mailings.Renderer.LiquidCache do
  @moduledoc """
  Parsing Liquid templates with Solid is relatively resource intensive.
  In order to preserve system resources when sending large campaigns or
  campaigns with large templates, BodyRenderer modules may use this module
  to cache parsed Liquid templates.
  """

  use GenServer

  @ttl :timer.minutes(10)
  @max_entries 500
  @evict_interval :timer.seconds(30)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec get(String.t(), (-> term())) :: term()
  def get(sha256, fun) do
    cached_template = GenServer.call(__MODULE__, {:get, sha256})

    if cached_template do
      cached_template
    else
      fun.() |> tap(&GenServer.cast(__MODULE__, {:set, sha256, &1}))
    end
  end

  @impl true
  def init(_) do
    table = :ets.new(:liquid_cache, [:set, :protected, {:read_concurrency, true}])
    schedule_evict()

    {:ok, table}
  end

  @impl true
  def handle_call({:get, sha256}, _, table) do
    case :ets.lookup(table, sha256) do
      [{sha256, template, _}] ->
        :ets.update_element(table, sha256, {3, now()})
        {:reply, template, table}

      [] ->
        {:reply, nil, table}
    end
  end

  @impl true
  def handle_cast({:set, sha256, template}, table) do
    :ets.insert(table, {sha256, template, now()})

    {:noreply, table}
  end

  @impl true
  def handle_info(:evict, table) do
    schedule_evict()

    cutoff = now() - @ttl

    {entries, expired_entries} =
      table
      |> :ets.tab2list()
      |> Enum.split_with(fn {_, _, timestamp} -> timestamp >= cutoff end)

    Enum.each(expired_entries, fn {sha256, _, _} -> :ets.delete(table, sha256) end)

    count = length(entries)

    if count > @max_entries do
      entries
      |> Enum.sort_by(fn {_, _, timestamp} -> timestamp end, :desc)
      |> Enum.drop(@max_entries)
      |> Enum.each(fn {sha256, _, _} -> :ets.delete(table, sha256) end)
    end

    {:noreply, table}
  end

  defp now() do
    System.monotonic_time(:millisecond)
  end

  defp schedule_evict() do
    Process.send_after(self(), :evict, @evict_interval)
  end
end
