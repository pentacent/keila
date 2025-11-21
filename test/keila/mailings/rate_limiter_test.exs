defmodule Keila.Mailings.RateLimiterAdapterTest do
  use ExUnit.Case, async: false
  alias Keila.Mailings.RateLimiter

  setup do
    RateLimiter.reset()
    on_exit(fn -> Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: nil) end)
  end

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

      additional_entries = for n <- 1..120, do: new_entry(n)
      additional_entries = additional_entries |> Enum.map(&process_entry(&1, sender))
      last_original_entry = Enum.at(third_pass, -1)

      # Some entries might be accepted depending on the timing, but most will be scheduled.
      assert additional_entries |> Enum.count(& &1.accepted_at) < 20

      assert additional_entries
             |> Enum.all?(fn entry ->
               entry.accepted_at ||
                 DateTime.after?(entry.schedule_at, last_original_entry.schedule_at)
             end)
    end
  end

  describe "check_rate_limit/3 with adapter rate limits" do
    test "enforces adapter rate limit" do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [second: 5])

      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          type: "test",
          rate_limit_per_second: 100
        },
        shared_sender: nil
      }

      wait_until_next_second()

      entries = for n <- 1..10, do: new_entry(n)
      results = entries |> Enum.map(&process_entry(&1, sender))

      assert Enum.count(results, & &1.accepted_at) == 5
      assert Enum.count(results, & &1.schedule_at) == 5
    end

    test "enforces adapter-wide rate limits across multiple senders" do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [second: 5])

      sender1 = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          type: "test",
          rate_limit_per_second: 100
        },
        shared_sender: nil
      }

      sender2 = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          type: "test",
          rate_limit_per_second: 100
        },
        shared_sender: nil
      }

      wait_until_next_second()

      # Process 3 with sender1
      results1 = for n <- 1..3, do: process_entry(new_entry(n), sender1)
      accepted1 = Enum.count(results1, & &1.accepted_at)
      assert accepted1 == 3

      # Process 3 with sender2 - should only get 2 (adapter limit is 5)
      results2 = for n <- 4..6, do: process_entry(new_entry(n), sender2)
      accepted2 = Enum.count(results2, & &1.accepted_at)
      assert accepted2 == 2
    end

    test "respects most restrictive limit between sender and adapter" do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [second: 5])

      restrictive_sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          type: "test",
          rate_limit_per_second: 2
        },
        shared_sender: nil
      }

      wait_until_next_second()

      # Should only accept 2 due to sender limit
      results = for n <- 1..5, do: process_entry(new_entry(n), restrictive_sender)
      accepted = Enum.count(results, & &1.accepted_at)
      assert accepted == 2
    end

    test "also works with adapter rate limits beyond seconds" do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [hour: 3])

      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          type: "test",
          rate_limit_per_second: 2,
          rate_limit_per_hour: 5
        },
        shared_sender: nil
      }

      wait_until_next_second()

      first_pass = for n <- 1..4, do: process_entry(new_entry(n), sender)

      wait_until_next_second(1)

      second_pass = for entry <- first_pass, do: process_entry(entry, sender)

      assert Enum.count(first_pass, & &1.accepted_at) == 2
      assert Enum.count(second_pass, & &1.accepted_at) == 3

      in_59_minutes = DateTime.utc_now() |> DateTime.add(59, :minute)
      in_61_minutes = DateTime.utc_now() |> DateTime.add(61, :minute)

      assert Enum.find(second_pass, fn entry ->
               !entry.accepted_at && DateTime.after?(entry.schedule_at, in_59_minutes) &&
                 DateTime.before?(entry.schedule_at, in_61_minutes)
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
    now = DateTime.utc_now(:second)

    if DateTime.compare(schedule_at, now) in [:lt, :eq] do
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
