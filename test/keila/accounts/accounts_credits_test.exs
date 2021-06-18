defmodule Keila.AccountsTest.Credits do
  use Keila.DataCase, async: false
  alias Keila.Accounts

  setup do
    root = insert!(:group)
    account = insert!(:account, group: root)

    credits_enabled_before? =
      Application.get_env(:keila, Keila.Accounts, [])
      |> Keyword.get(:credits_enabled, false)

    set_credits_enabled(true)
    on_exit(fn -> set_credits_enabled(credits_enabled_before?) end)

    %{account: account}
  end

  @tag :accounts
  test "add and check credits", %{account: account} do
    assert true == Accounts.credits_enabled?()
    assert false == Accounts.has_credits?(account.id, 1)

    assert :ok = Accounts.add_credits(account.id, 10, tomorrow())
    assert :ok = Accounts.add_credits(account.id, 5, after_tomorrow())

    assert true == Accounts.has_credits?(account.id, 5)
    assert true == Accounts.has_credits?(account.id, 10)
    assert true == Accounts.has_credits?(account.id, 15)
    assert false == Accounts.has_credits?(account.id, 16)

    assert {15, 15} == Accounts.get_credits(account.id)
  end

  @tag :accounts
  test "add and consume credits", %{account: account} do
    tomorrow = tomorrow()
    after_tomorrow = after_tomorrow()

    assert :ok = Accounts.add_credits(account.id, 10, tomorrow)
    assert :ok = Accounts.add_credits(account.id, 5, after_tomorrow)

    assert :ok == Accounts.consume_credits(account.id, 12)
    assert :error == Accounts.consume_credits(account.id, 5)

    ledger = Keila.Repo.all(Accounts.CreditTransaction)
    assert Enum.find(ledger, &(&1.amount == -10 && &1.expires_at == tomorrow))
    assert Enum.find(ledger, &(&1.amount == -2 && &1.expires_at == after_tomorrow))

    assert {15, 3} == Accounts.get_credits(account.id)
  end

  defp set_credits_enabled(enable?) do
    config =
      Application.get_env(:keila, Keila.Accounts, [])
      |> Keyword.put(:credits_enabled, enable?)

    Application.put_env(:keila, Keila.Accounts, config)
  end

  defp tomorrow,
    do: DateTime.utc_now() |> DateTime.add(24 * 60 * 60, :second) |> DateTime.truncate(:second)

  defp after_tomorrow,
    do:
      DateTime.utc_now() |> DateTime.add(2 * 24 * 60 * 60, :second) |> DateTime.truncate(:second)
end
