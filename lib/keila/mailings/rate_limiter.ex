defmodule Keila.Mailings.RateLimiter do
  @moduledoc """
  Module for enforcing Sender-based rate limits and scheduling sending emails.
  """

  use GenServer

  require Logger
  alias Keila.Mailings.{Sender, SenderAdapters}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @type unit :: :second | :minute | :hour
  @type rate_limit :: {unit(), limit :: integer()}
  @type rate_limit_entry :: {key :: term(), unit(), limit :: integer()}
  @type schedule_at_result ::
          {schedule_at :: DateTime.t(), scheduling_requested_at :: DateTime.t()}

  @doc """
  Checks the rate limit for the given sender. Returns `:ok` if the rate limit has not been exceeded
  and else an `:error` tuple with a `schedule_at_result()` tuple.
  """
  @spec check_sender_rate_limit(Sender.t(), DateTime.t() | nil) ::
          :ok | {:error, schedule_at_result()}
  def check_sender_rate_limit(sender, scheduling_requested_at \\ nil) do
    sender = sender.shared_sender || sender
    rate_limit_entries = get_rate_limit_entries(sender)
    GenServer.call(__MODULE__, {:check_rate_limit, rate_limit_entries, scheduling_requested_at})
  end

  @doc """
  Returns a timestamp for when capacity is going to be available for the given Sender in the future.
  """
  @spec get_sender_schedule_at(Sender.t()) :: schedule_at_result()
  def get_sender_schedule_at(sender) do
    sender = sender.shared_sender || sender
    rate_limit_entries = get_rate_limit_entries(sender)
    GenServer.call(__MODULE__, {:get_schedule_at, rate_limit_entries})
  end

  @doc """
  Resets all rate limit buckets.
  """
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  # Get all rate limit entries as {key, unit, limit} tuples
  # ordered by unit from smallest to largest.
  defp get_rate_limit_entries(sender) do
    adapter = SenderAdapters.get_adapter(sender.config.type)

    sender_entries = get_sender_limit_entries(sender, adapter)
    adapter_entries = get_adapter_limit_entries(sender, adapter)

    (sender_entries ++ adapter_entries)
    |> Enum.sort_by(fn {_, unit, _} -> scale(unit) end)
  end

  defp get_sender_limit_entries(sender, adapter) do
    key = {:sender, sender.id}

    if adapter && function_exported?(adapter, :rate_limit, 1) do
      adapter.rate_limit(sender)
    else
      [
        {:second, sender.config.rate_limit_per_second},
        {:minute, sender.config.rate_limit_per_minute},
        {:hour, sender.config.rate_limit_per_hour}
      ]
    end
    |> Enum.reject(fn {_unit, limit} -> is_nil(limit) end)
    |> Enum.map(fn {unit, limit} -> {key, unit, limit} end)
  end

  defp get_adapter_limit_entries(sender, adapter) do
    if adapter && function_exported?(adapter, :adapter_rate_limit, 0) do
      key = {:adapter, sender.config.type}

      adapter.adapter_rate_limit()
      |> Enum.reject(fn {_unit, limit} -> is_nil(limit) end)
      |> Enum.map(fn {unit, limit} -> {key, unit, limit} end)
    else
      []
    end
  end

  # GenServer implementation

  @impl true
  def init(_) do
    ets_table = :ets.new(:rate_limiter_schedule, [:set, :protected])

    {:ok, %{ets_table: ets_table}}
  end

  @impl true
  def handle_call({:check_rate_limit, rate_limit_entries, scheduling_requested_at}, _from, state) do
    ets_table = state.ets_table

    with :ok <- precheck_rate_limits(rate_limit_entries),
         :ok <- check_rate_limits(rate_limit_entries) do
      rate_limit_entries
      |> keys()
      |> Enum.each(fn key ->
        if not was_scheduled?(ets_table, key, scheduling_requested_at) do
          update_counter(ets_table, key)
        end
      end)

      {:reply, :ok, state}
    else
      :error ->
        {:reply, {:error, get_schedule_at(ets_table, rate_limit_entries)}, state}
    end
  end

  def handle_call({:get_schedule_at, rate_limit_entries}, _from, state) do
    ets_table = state.ets_table
    {:reply, get_schedule_at(ets_table, rate_limit_entries), state}
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    {:reply, :ok, state}
  end

  defp get_schedule_at(ets_table, rate_limit_entries) do
    now = DateTime.utc_now(:second)

    # Group by key to calculate schedule for each unique key
    entries_by_key =
      rate_limit_entries
      |> Enum.group_by(fn {key, _, _} -> key end)

    schedules =
      entries_by_key
      |> Enum.map(fn {key, entries} ->
        limits = Enum.map(entries, fn {_, unit, limit} -> {unit, limit} end)
        do_get_schedule_at(ets_table, key, limits)
      end)
      |> Enum.filter(& &1)

    case schedules do
      [] ->
        {now, now}

      _ ->
        # Return the most restrictive (latest) schedule
        Enum.max_by(schedules, fn {schedule_at, _} -> schedule_at end, DateTime)
    end
  end

  # Inspect buckets to see if any have already been exhausted
  defp precheck_rate_limits(rate_limit_entries) do
    rate_limit_entries
    |> Enum.reduce_while(:ok, fn {key, unit, limit}, :ok ->
      bucket = bucket_name(key, unit)
      scale = scale(unit)

      case ExRated.inspect_bucket(bucket, scale, limit) do
        {count, _count_remaining, _ms_to_next_bucket, _created_at, _updated_at}
        when count >= limit ->
          {:halt, :error}

        _ ->
          {:cont, :ok}
      end
    end)
  end

  # Check rate limits in reverse order (starting with smallest scales)
  defp check_rate_limits(rate_limit_entries) do
    rate_limit_entries
    |> Enum.reverse()
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case do_check_rate_limit(entry) do
        :ok -> {:cont, :ok}
        :error -> {:halt, :error}
      end
    end)
  end

  defp do_check_rate_limit({key, unit, limit}) do
    bucket = bucket_name(key, unit)
    scale = scale(unit)

    case ExRated.check_rate(bucket, scale, limit) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp keys(rate_limit_entries) do
    rate_limit_entries
    |> Enum.map(fn {key, _, _} -> key end)
    |> Enum.uniq()
  end

  defp was_scheduled?(ets_table, key, scheduling_requested_at)

  defp was_scheduled?(_ets_table, _key, nil), do: false

  defp was_scheduled?(ets_table, key, scheduling_requested_at) do
    exists? = :ets.member(ets_table, key)
    schedule_start = exists? && :ets.lookup_element(ets_table, key, 3)

    exists? and not DateTime.before?(scheduling_requested_at, schedule_start)
  end

  defp bucket_name(key, unit) do
    "#{inspect(key)}:#{unit}"
  end

  defp update_counter(ets_table, key) do
    start_datetime = DateTime.utc_now(:second) |> DateTime.add(1, :second)

    if :ets.insert_new(ets_table, {key, 0, start_datetime}) do
      0
    else
      :ets.update_counter(ets_table, key, {2, 1})
    end
  end

  def do_get_schedule_at(ets_table, key, rate_limits) do
    i = update_counter(ets_table, key)
    start_datetime = :ets.lookup_element(ets_table, key, 3)

    rate_limits
    |> Enum.filter(fn {_, limit} -> is_number(limit) && limit > 0 end)
    |> Enum.map(fn {scale_name, limit} ->
      scale(scale_name) * div(i, limit)
    end)
    |> Enum.sum()
    |> then(fn ms ->
      schedule_at = DateTime.add(start_datetime, div(ms, 1000))
      now = DateTime.utc_now(:second)

      if DateTime.diff(schedule_at, now) >= 0 do
        {schedule_at, now}
      else
        :ets.delete(ets_table, key)
        do_get_schedule_at(ets_table, key, rate_limits)
      end
    end)
  end

  defp scale(scale_name)
  defp scale(:second), do: 1_000
  defp scale(:minute), do: 60_000
  defp scale(:hour), do: 3_600_000
end
