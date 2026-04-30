defmodule Keila.Mailings.RateLimiterTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.RateLimiter

  setup_all do
    Code.ensure_loaded?(Keila.TestSenderAdapter)
    :ok
  end

  setup do
    table = RateLimiter.new_table()
    on_exit(fn -> Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: nil) end)
    %{table: table}
  end

  describe "get_sender_tokens/2" do
    test "returns amount of tokens currently available for a given sender", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_hour: 30,
          rate_limit_per_minute: 20,
          rate_limit_per_second: 10
        },
        shared_sender: nil
      }

      assert RateLimiter.get_sender_tokens(table, sender) == 10

      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_hour: 30
        },
        shared_sender: nil
      }

      assert RateLimiter.get_sender_tokens(table, sender) == 30
    end

    test "returns :infinity if there are no rate limits configured", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{},
        shared_sender: nil
      }

      assert RateLimiter.get_sender_tokens(table, sender) == :infinity
    end
  end

  describe "consume_sender_tokens/3" do
    test "tokens are consumed across multiple dimensions", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_minute: 9,
          rate_limit_per_second: 5
        },
        shared_sender: nil
      }

      assert RateLimiter.consume_sender_tokens(table, sender, 5) == :ok
      assert RateLimiter.consume_sender_tokens(table, sender, 1) == :error
      :timer.sleep(1000)
      assert RateLimiter.consume_sender_tokens(table, sender, 4) == :ok
      assert RateLimiter.consume_sender_tokens(table, sender, 1) == :error
    end

    test "no tokens are consumed when rate limit is exceeded", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_second: 5
        },
        shared_sender: nil
      }

      assert RateLimiter.consume_sender_tokens(table, sender, 6) == :error
      assert RateLimiter.consume_sender_tokens(table, sender, 5) == :ok
    end

    test "tokens are refilled correctly", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_second: 5
        },
        shared_sender: nil
      }

      for _n <- 1..5 do
        assert RateLimiter.consume_sender_tokens(table, sender, 1)
        :timer.sleep(200)
      end

      assert RateLimiter.get_sender_tokens(table, sender) == 5
    end
  end

  describe "get_adapter_tokens/2" do
    test "returns number of available tokens if adapter implements rate limits", %{table: table} do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [second: 5])
      assert RateLimiter.get_adapter_tokens(table, Keila.TestSenderAdapter) == 5
    end

    test "returns :infinity if there are no rate limits configured for the adapter", %{
      table: table
    } do
      Application.put_env(:keila, Keila.TestSenderAdapter, rate_limit: [])

      assert RateLimiter.get_adapter_tokens(table, Keila.TestSenderAdapter) == :infinity
    end
  end

  describe "reset/1" do
    test "clears all buckets", %{table: table} do
      sender = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{
          rate_limit_per_second: 5
        },
        shared_sender: nil
      }

      assert RateLimiter.consume_sender_tokens(table, sender, 3) == :ok
      assert RateLimiter.get_sender_tokens(table, sender) == 2

      RateLimiter.reset(table)

      assert RateLimiter.get_sender_tokens(table, sender) == 5
    end
  end

  describe "persist/1 and restore/1" do
    test "stores and cleans + restores rate limiter state" do
      sender1 = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{rate_limit_per_minute: 5}
      }

      sender2 = %Keila.Mailings.Sender{
        id: Ecto.UUID.generate(),
        config: %Keila.Mailings.Sender.Config{rate_limit_per_minute: 5}
      }

      table1 = RateLimiter.new_table()
      assert RateLimiter.consume_sender_tokens(table1, sender1, 5) == :ok
      assert RateLimiter.persist(table1) == :ok

      table2 = RateLimiter.new_table()
      assert RateLimiter.consume_sender_tokens(table2, sender2, 5) == :ok
      assert RateLimiter.restore(table2) == :ok

      assert RateLimiter.get_sender_tokens(table2, sender1) == 0
      assert RateLimiter.get_sender_tokens(table2, sender2) == 5
    end
  end
end
