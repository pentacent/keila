defmodule Keila.Mailings.Renderer.LiquidCache do
  @moduledoc """
  Parsing Liquid templates with Solid is relatively resource intensive.
  In order to preserve system resources when sending large campaigns or
  campaigns with large templates, BodyRenderer modules may use this module
  to cache parsed Liquid templates.
  """

  use GenServer

  @table __MODULE__
  @ttl :timer.minutes(10)
  @max_entries 500
  @evict_interval :timer.seconds(30)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Fetches an entry by the `sha256` key or executes and persists
  the result of `fun/0` if the key is not present.
  """
  @spec get(binary(), (-> term())) :: term()
  def get(sha256, fun) do
    cached_template = get_from_cache(sha256)

    if cached_template do
      cached_template
    else
      fun.() |> tap(&write_to_cache(sha256, &1))
    end
  rescue
    ArgumentError -> fun.()
  end

  @spec ttl() :: pos_integer()
  def ttl(), do: @ttl

  @spec max_entries() :: pos_integer()
  def max_entries(), do: @max_entries

  defp get_from_cache(sha256) do
    case :ets.lookup(@table, sha256) do
      [{^sha256, template, _}] ->
        :ets.update_element(@table, sha256, {3, now()})
        template

      [] ->
        nil
    end
  end

  defp write_to_cache(sha256, template) do
    :ets.insert(@table, {sha256, template, now()})
  end

  @impl true
  def init(_) do
    table =
      :ets.new(@table, [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])

    schedule_evict()

    {:ok, table}
  end

  # :ets.fun2ms(fn {sha256, _, timestamp} -> {sha256, timestamp} end)
  @timestamp_ms [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}]

  @impl true
  def handle_info(:evict, table) do
    schedule_evict()

    cutoff = now() - @ttl

    {entries, expired_entries} =
      table
      |> :ets.select(@timestamp_ms)
      |> Enum.split_with(fn {_, timestamp} -> timestamp >= cutoff end)

    Enum.each(expired_entries, fn {sha256, _} -> :ets.delete(table, sha256) end)

    count = length(entries)

    if count > @max_entries do
      entries
      |> Enum.sort_by(fn {_, timestamp} -> timestamp end, :desc)
      |> Enum.drop(@max_entries)
      |> Enum.each(fn {sha256, _} -> :ets.delete(table, sha256) end)
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
