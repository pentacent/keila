defmodule Keila.Mailings.RateLimiterTest do
  use ExUnit.Case
  alias Keila.Mailings.RateLimiter

  describe "check_rate_limit/3" do
    test "rate-limits and returns schedule datetime when exceeding rate limit" do
      entries = for n <- 1..120, do: new_entry(n)

      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_hour: 30,
          rate_limit_per_minute: 20,
          rate_limit_per_second: 10
        },
        shared_sender: nil
      }

      wait_until_next_second()

      first_pass =
        entries
        |> Enum.map(&process_entry(&1, sender))

      wait_until_next_second(1)

      second_pass =
        first_pass
        |> Enum.map(&process_entry(&1, sender))

      wait_until_next_second(1)

      third_pass =
        second_pass
        |> Enum.map(&process_entry(&1, sender))

      assert first_pass |> Enum.slice(0, 10) |> Enum.all?(& &1.accepted_at)
      refute first_pass |> Enum.slice(10, 110) |> Enum.any?(& &1.accepted_at)

      assert second_pass |> Enum.slice(0, 20) |> Enum.all?(& &1.accepted_at)
      refute second_pass |> Enum.slice(20, 100) |> Enum.any?(& &1.accepted_at)

      assert third_pass == second_pass

      additional_entries = for n <- 121..10, do: new_entry(n)
      additional_entries = additional_entries |> Enum.map(&process_entry(&1, sender))
      last_original_entry = Enum.at(third_pass, -1)

      assert additional_entries
             |> Enum.all?(fn entry ->
               DateTime.after?(entry.schedule_at, last_original_entry.schedule_at)
             end)
    end
  end

  defp wait_until_next_second(additional_seconds \\ 0) do
    now = DateTime.utc_now()
    {current_microseconds, _} = now.microsecond
    until_next_second = 1000 - div(current_microseconds, 1000)
    :timer.sleep(until_next_second + additional_seconds * 1000)
    DateTime.utc_now()
  end

  defp new_entry(n) do
    %{id: n, schedule_at: nil, scheduling_requested_at: nil, accepted_at: nil}
  end

  defp process_entry(%{accepted_at: accepted_at} = entry, _sender)
       when not is_nil(accepted_at) do
    entry
  end

  defp process_entry(%{schedule_at: schedule_at} = entry, sender)
       when not is_nil(schedule_at) do
    now = DateTime.utc_now()

    if DateTime.before?(schedule_at, now) do
      do_process_entry(entry, sender)
    else
      entry
    end
  end

  defp process_entry(entry, sender), do: do_process_entry(entry, sender)

  defp do_process_entry(entry, sender) do
    case RateLimiter.check_sender_rate_limit(sender, entry.scheduling_requested_at) do
      {:error, {schedule_at, scheduling_requested_at}} ->
        entry
        |> Map.put(:schedule_at, schedule_at)
        |> Map.put(:scheduling_requested_at, scheduling_requested_at)

      :ok ->
        entry |> Map.put(:accepted_at, DateTime.utc_now())
    end
  end
end
