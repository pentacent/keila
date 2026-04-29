defmodule Keila.Mailings.RateLimiter do
  @moduledoc """
  Module for enforcing Sender-based and Adapter-based rate limits implemented
  using the token bucket algorithm.

  The module supports persisting and restoring its state to/from the database.
  Restoring the persisted state does not take into account time that may have
  passed since the state was last persisted. This means that the token refill
  timers will resume from the moment the state was last persisted.
  """

  require Logger
  alias Keila.Mailings.{Sender, RateLimiterState}

  @type unit :: :second | :minute | :hour
  @type rate_limit :: {unit(), capacity :: integer()}
  @type tokens :: integer() | :infinity
  @type table :: :ets.table()

  @doc """
  Creates a new ETS table for rate limiter buckets.
  """
  @spec new_table() :: table()
  def new_table() do
    :ets.new(:rate_limiter_buckets, [:set, :public])
  end

  @doc """
  Deletes the given ETS table.
  """
  @spec delete_table(table()) :: :ok
  def delete_table(table) do
    :ets.delete(table)
    :ok
  end

  @doc """
  Clears all rate limit buckets.
  """
  @spec reset(table()) :: :ok
  def reset(table) do
    :ets.delete_all_objects(table)
    :ok
  end

  @doc """
  Returns the number of tokens available for the given sender.
  """
  @spec get_sender_tokens(table(), Sender.t()) :: tokens()
  def get_sender_tokens(table, sender) do
    id = get_id(sender)
    limits = get_sender_limits(sender)
    get_tokens(table, id, limits) |> Enum.map(&elem(&1, 0)) |> Enum.min()
  end

  @doc """
  Consumes the given number of tokens for the given sender.
  """
  @spec consume_sender_tokens(table(), Sender.t(), amount :: integer()) :: :ok | :error
  def consume_sender_tokens(table, sender, amount \\ 1) do
    id = get_id(sender)
    limits = get_sender_limits(sender)
    consume_tokens(table, id, limits, amount)
  end

  @doc """
  Returns the number of tokens available for the given adapter module.
  """
  @spec get_adapter_tokens(table(), adapter :: atom()) :: tokens()
  def get_adapter_tokens(table, adapter) do
    id = get_id(adapter)
    limits = get_adapter_limits(adapter)
    get_tokens(table, id, limits) |> Enum.map(&elem(&1, 0)) |> Enum.min()
  end

  @doc """
  Returns the bucket capacity configured for the given sender.

  Returns `:infinity` if the sender has no rate limits configured.
  """
  @spec get_sender_capacity(Sender.t()) :: tokens()
  def get_sender_capacity(sender) do
    get_sender_limits(sender)
    |> Enum.map(fn {_unit, capacity} -> capacity end)
    |> Enum.min()
  end

  @doc """
  Returns the bucket capacity configured for the given adapter module.

  Returns `:infinity` if the adapter has no rate limits configured.
  """
  @spec get_adapter_capacity(adapter :: atom()) :: tokens()
  def get_adapter_capacity(adapter) do
    get_adapter_limits(adapter)
    |> Enum.map(fn {_unit, capacity} -> capacity end)
    |> Enum.min()
  end

  @doc """
  Consumes the given number of tokens for the given adapter module.
  """
  @spec consume_adapter_tokens(table(), adapter :: atom(), amount :: integer()) :: :ok | :error
  def consume_adapter_tokens(table, adapter, amount \\ 1) do
    id = get_id(adapter)
    limits = get_adapter_limits(adapter)
    consume_tokens(table, id, limits, amount)
  end

  @doc """
  Persists the current rate limiter state to the database.

  Converts monotonic timestamps to relative ages so the data is portable
  across VM restarts.
  """
  @spec persist(table()) :: :ok | :error
  def persist(table) do
    now = now()

    entries =
      :ets.tab2list(table)
      |> Enum.map(fn {key, tokens, updated_at} ->
        {key, tokens, now - updated_at}
      end)

    data = :erlang.term_to_binary(entries)

    RateLimiterState.changeset(%{id: 1, data: data})
    |> Keila.Repo.insert(
      on_conflict: {:replace, [:data, :updated_at]},
      conflict_target: :id
    )
    |> case do
      {:ok, _} ->
        Logger.debug("RateLimiter: persisted state to database")
        :ok

      {:error, reason} ->
        Logger.warning("RateLimiter: failed to persist state: #{inspect(reason)}")
        :error
    end
  end

  @doc """
  Restores the rate limiter state from the database.
  """
  @spec restore(table()) :: :ok
  def restore(table) do
    case Keila.Repo.get(RateLimiterState, 1) do
      %RateLimiterState{data: data} when not is_nil(data) ->
        now = now()
        entries = :erlang.binary_to_term(data)
        reset(table)

        Enum.each(entries, fn {key, tokens, age_ms} ->
          :ets.insert(table, {key, tokens, now - age_ms})
        end)

        Logger.info("RateLimiter: restored #{length(entries)} bucket(s) from database")

      _ ->
        Logger.debug("RateLimiter: no persisted state found")
        :ok
    end
  end

  defp get_id(%{id: id}) when not is_nil(id), do: get_id(id)
  defp get_id(term), do: :erlang.phash2(term)

  defp get_sender_limits(%Sender{config: config}) do
    [
      {:hour, config.rate_limit_per_hour},
      {:minute, config.rate_limit_per_minute},
      {:second, config.rate_limit_per_second}
    ]
    |> Enum.reject(fn {_unit, limit} -> is_nil(limit) end)
    |> then(fn
      [] -> [{:second, :infinity}]
      limits -> limits
    end)
  end

  defp get_adapter_limits(adapter) do
    if function_exported?(adapter, :adapter_rate_limit, 0) do
      adapter.adapter_rate_limit()
    else
      []
    end
    |> Enum.reject(fn {_unit, limit} -> is_nil(limit) end)
    |> then(fn
      [] -> [{:second, :infinity}]
      limits -> limits
    end)
  end

  defp get_tokens(table, id, limits) do
    now = now()

    Enum.map(limits, fn
      {_, :infinity} ->
        {:infinity, now}

      {unit, capacity} ->
        if :ets.insert_new(table, {{id, unit}, capacity, now}) do
          {capacity, now}
        else
          [{_, tokens, updated_at}] = :ets.lookup(table, {id, unit})
          refilled_tokens(unit, capacity, tokens, updated_at, now)
        end
    end)
  end

  defp consume_tokens(table, id, limits, amount) do
    tokens = get_tokens(table, id, limits)

    if Enum.all?(tokens, &(elem(&1, 0) >= amount)) do
      Enum.zip(limits, tokens)
      |> Enum.each(fn
        {{_unit, :infinity}, _} ->
          :ok

        {{unit, _capacity}, {tokens, updated_at}} ->
          :ets.update_element(table, {id, unit}, [{2, tokens - amount}, {3, updated_at}])
      end)
    else
      :error
    end
  end

  defp refilled_tokens(unit, capacity, current_tokens, updated_at, now) do
    unit_ms = unit_to_ms(unit)
    ticks = div(now - updated_at, unit_ms)
    tokens = min(capacity, current_tokens + ticks * capacity)
    updated_at = updated_at + ticks * unit_ms

    {tokens, updated_at}
  end

  defp unit_to_ms(:second), do: 1_000
  defp unit_to_ms(:minute), do: 60_000
  defp unit_to_ms(:hour), do: 3_600_000

  defp now(), do: System.monotonic_time(:millisecond)
end
