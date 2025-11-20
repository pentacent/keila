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
  @type schedule_at_result ::
          {schedule_at :: DateTime.t(), scheduling_requested_at :: DateTime.t()}
  @doc """
  Checks the rate limit for the given sender. Returns `:ok` if the rate limit has not been exceeded
  and else an `:error` tuple with a `schedule_at_result()` tuple.
  """
  @spec check_sender_rate_limit(Sender.Id.t(), DateTime.t() | nil) ::
          :ok | {:error, schedule_at_result()}
  def check_sender_rate_limit(sender, scheduling_requested_at \\ nil) do
    sender = sender.shared_sender || sender
    rate_limits = get_rate_limits(sender)
    key = ets_key(sender.id, rate_limits)
    GenServer.call(__MODULE__, {:check_rate_limit, key, rate_limits, scheduling_requested_at})
  end

  @doc """
  Returns a timestamp for when capacity is going to be available for the given Sender in the future.
  """
  @spec get_sender_schedule_at(Sender.t()) :: schedule_at_result()
  def get_sender_schedule_at(sender) do
    sender = sender.shared_sender || sender
    rate_limits = get_rate_limits(sender)
    key = ets_key(sender.id, rate_limits)
    GenServer.call(__MODULE__, {:get_schedule_at, key, rate_limits})
  end

  # List rate limits with larger scale first
  defp get_rate_limits(sender) do
    adapter = SenderAdapters.get_adapter(sender.config.type)

    if adapter && function_exported?(adapter, :rate_limit, 1) do
      adapter.rate_limit(sender)
    else
      get_sender_config_rate_limits(sender)
    end
    |> Enum.reject(fn {_unit, limit} -> is_nil(limit) end)
  end

  defp get_sender_config_rate_limits(sender) do
    [
      {:hour, sender.config.rate_limit_per_hour},
      {:minute, sender.config.rate_limit_per_minute},
      {:second, sender.config.rate_limit_per_second}
    ]
  end

  defp ets_key(sender_id, rate_limits) do
    :erlang.phash2({sender_id, rate_limits})
  end

  # GenServer implementation

  @impl true
  def init(_) do
    ets_table = :ets.new(:user_lookup, [:set, :protected])

    {:ok, %{ets_table: ets_table}}
  end

  @impl true
  def handle_call({:check_rate_limit, key, rate_limits, scheduling_requested_at}, _from, state) do
    ets_table = state.ets_table

    with :ok <- precheck_rate_limits(key, rate_limits),
         :ok <- check_rate_limits(key, rate_limits) do
      if not was_scheduled?(ets_table, key, scheduling_requested_at),
        do: update_counter(ets_table, key)

      {:reply, :ok, state}
    else
      :error ->
        {:reply, {:error, do_get_schedule_at(ets_table, key, rate_limits)}, state}
    end
  end

  def handle_call({:get_schedule_at, key, rate_limits}, _from, state) do
    ets_table = state.ets_table
    {:reply, do_get_schedule_at(ets_table, key, rate_limits), state}
  end

  defp was_scheduled?(ets_table, key, scheduling_requested_at)

  defp was_scheduled?(_ets_table, _key, nil), do: false

  defp was_scheduled?(ets_table, key, scheduling_requested_at) do
    exists? = :ets.member(ets_table, key)
    schedule_start = exists? && :ets.lookup_element(ets_table, key, 3)

    exists? and not DateTime.before?(scheduling_requested_at, schedule_start)
  end

  # Inspect buckets to see if buckets have already been exhausted
  defp precheck_rate_limits(key, rate_limits) do
    rate_limits
    |> Enum.reduce_while(:ok, fn rate_limit, :ok ->
      case do_precheck_rate_limit(key, rate_limit) do
        :ok -> {:cont, :ok}
        :error -> {:halt, :error}
      end
    end)
  end

  defp do_precheck_rate_limit(key, {scale_name, limit})
       when is_integer(limit) and limit > 0 do
    bucket = bucket_name(key, scale_name)
    scale = scale(scale_name)

    case ExRated.inspect_bucket(bucket, scale, limit) do
      {_, remaining, _, _, _} when remaining > 0 -> :ok
      _ -> :error
    end
  end

  defp do_precheck_rate_limit(_, _), do: :ok

  # Check rate limits in reversed order (starting with smaller scales)
  defp check_rate_limits(key, rate_limits) do
    rate_limits
    |> Enum.reverse()
    |> Enum.reduce_while(:ok, fn rate_limit, :ok ->
      case do_check_rate_limit(key, rate_limit) do
        :ok -> {:cont, :ok}
        :error -> {:halt, :error}
      end
    end)
  end

  defp do_check_rate_limit(key, {scale_name, limit}) when is_integer(limit) and limit > 0 do
    bucket = bucket_name(key, scale_name)
    scale = scale(scale_name)

    case ExRated.check_rate(bucket, scale, limit) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp bucket_name(key, scale_name) do
    "#{key}:#{scale_name}"
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
      unit =
        case scale_name do
          :second -> 1
          :minute -> 60
          :hour -> 60 * 60
        end

      unit * div(i, limit)
    end)
    |> Enum.sum()
    |> then(fn seconds ->
      schedule_at = DateTime.add(start_datetime, seconds)
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
