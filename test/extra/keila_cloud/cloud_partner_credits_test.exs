require Keila

Keila.if_cloud do
  defmodule KeilaCloud.PartnersTest.PartnerCredits do
    use Keila.DataCase, async: false

    alias Keila.Accounts
    alias Keila.Accounts.CreditTransaction
    alias KeilaCloud.Partners

    import Ecto.Query

    setup do
      root_group = insert!(:group)
      partner_account = insert!(:account, group: root_group)
      partner_user = insert!(:user)
      Accounts.set_user_account(partner_user.id, partner_account.id)

      child1_group = insert!(:group, parent: root_group)
      child1 = insert!(:account, group: child1_group, parent_id: partner_account.id)

      child2_group = insert!(:group, parent: root_group)
      child2 = insert!(:account, group: child2_group, parent_id: partner_account.id)

      credits_enabled_before? =
        Application.get_env(:keila, Keila.Accounts, [])
        |> Keyword.get(:credits_enabled, false)

      set_credits_enabled(true)
      on_exit(fn -> set_credits_enabled(credits_enabled_before?) end)

      {:ok, partner_account} = Partners.set_is_partner(partner_account.id, true)

      %{
        root_group: root_group,
        partner: partner_account,
        partner_user: partner_user,
        child1: child1,
        child2: child2
      }
    end

    describe "distribute_partner_transaction_credits/3 (current cycle)" do
      test "distributes configured amounts to children, debits partner",
           %{partner: partner, child1: child1, child2: child2} do
        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 100, child2.id => 200}
          })

        expires_at = in_days(30)
        :ok = Accounts.add_credits(partner.id, 1000, expires_at)

        :ok = Partners.distribute_partner_transaction_credits(partner.id, expires_at)

        assert {1000, 700} = Accounts.get_credits(partner.id)
        assert {100, 100} = Accounts.get_credits(child1.id)
        assert {200, 200} = Accounts.get_credits(child2.id)
      end

      test "skips and does not crash when partner has insufficient credits",
           %{partner: partner, child1: child1, child2: child2} do
        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 100, child2.id => 100}
          })

        expires_at = in_days(30)
        :ok = Accounts.add_credits(partner.id, 50, expires_at)

        :ok = Partners.distribute_partner_transaction_credits(partner.id, expires_at)

        assert {50, 50} = Accounts.get_credits(partner.id)
        assert {0, 0} = Accounts.get_credits(child1.id)
        assert {0, 0} = Accounts.get_credits(child2.id)
      end
    end

    describe "transfer_credits/3" do
      test "transfers credits from partner to child",
           %{partner: partner, child1: child1} do
        :ok = Accounts.add_credits(partner.id, 500, in_days(30))

        assert :ok = Partners.transfer_credits(partner.id, child1.id, 100)

        assert {500, 400} = Accounts.get_credits(partner.id)
        assert {100, 100} = Accounts.get_credits(child1.id)
      end

      test "child credits inherit the source cycle's expires_at, drawing earliest first",
           %{partner: partner, child1: child1} do
        near = in_days(7) |> DateTime.truncate(:second)
        far = in_days(60) |> DateTime.truncate(:second)
        :ok = Accounts.add_credits(partner.id, 50, near)
        :ok = Accounts.add_credits(partner.id, 100, far)

        assert :ok = Partners.transfer_credits(partner.id, child1.id, 75)

        child_transactions =
          list_credit_transactions(child1.id) |> Enum.filter(&(&1.amount > 0))

        assert [%{amount: 50, expires_at: ^near}, %{amount: 25, expires_at: ^far}] =
                 child_transactions
      end

      test "rejects when target is not a child of partner",
           %{partner: partner, root_group: root_group} do
        stranger_group = insert!(:group, parent: root_group)
        stranger = insert!(:account, group: stranger_group)

        :ok = Accounts.add_credits(partner.id, 500, in_days(30))

        assert {:error, :not_a_child} =
                 Partners.transfer_credits(partner.id, stranger.id, 100)
      end

      test "rejects when partner has insufficient credits",
           %{partner: partner, child1: child1} do
        :ok = Accounts.add_credits(partner.id, 50, in_days(30))

        assert {:error, :insufficient_credits} =
                 Partners.transfer_credits(partner.id, child1.id, 100)

        assert {50, 50} = Accounts.get_credits(partner.id)
      end
    end

    describe "distribute_partner_credits/1" do
      test "rebuilds all future-cycle child rows from current config",
           %{partner: partner, child1: child1} do
        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 50}
          })

        today = Date.utc_today()

        for n <- 0..11 do
          valid_from = today |> Date.shift(month: n) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
          expires_at = today |> Date.shift(month: n + 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
          :ok = Accounts.add_credits(partner.id, 1000, expires_at, valid_from)

          :ok =
            Partners.distribute_partner_transaction_credits(
              partner.id,
              expires_at,
              valid_from
            )
        end

        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 200}
          })

        :ok = Partners.distribute_partner_credits(partner.id)

        child_transactions =
          list_credit_transactions(child1.id) |> Enum.filter(&(&1.amount > 0))

        past_transactions = Enum.filter(child_transactions, &past_or_now?(&1.valid_from))
        future_transactions = Enum.filter(child_transactions, &future?(&1.valid_from))

        assert [%{amount: 50}] = past_transactions
        assert length(future_transactions) == 11
        assert Enum.all?(future_transactions, &(&1.amount == 200))
      end

      test "removing credit allocation removes transactions for future cycles",
           %{partner: partner, child1: child1, child2: child2} do
        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 100, child2.id => 100}
          })

        valid_from = in_days(15)
        expires_at = in_days(45)
        :ok = Accounts.add_credits(partner.id, 1000, expires_at, valid_from)
        :ok = Partners.distribute_partner_credits(partner.id)

        assert length(list_credit_transactions(child1.id)) == 1
        assert length(list_credit_transactions(child2.id)) == 1

        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 100}
          })

        :ok = Partners.distribute_partner_credits(partner.id)

        assert length(list_credit_transactions(child1.id)) == 1
        assert length(list_credit_transactions(child2.id)) == 0
      end

      test "manual current-cycle transfer survives reconciler",
           %{partner: partner, child1: child1} do
        {:ok, _} =
          Partners.update_partner_settings(partner.id, %{
            "credit_allocations" => %{child1.id => 50}
          })

        :ok = Accounts.add_credits(partner.id, 1000, in_days(30))
        :ok = Partners.transfer_credits(partner.id, child1.id, 75)

        assert {75, 75} = Accounts.get_credits(child1.id)

        :ok = Partners.distribute_partner_credits(partner.id)

        assert {75, 75} = Accounts.get_credits(child1.id)
      end
    end

    defp set_credits_enabled(enable?) do
      config =
        Application.get_env(:keila, Keila.Accounts, [])
        |> Keyword.put(:credits_enabled, enable?)

      Application.put_env(:keila, Keila.Accounts, config)
    end

    defp in_days(n),
      do:
        DateTime.utc_now()
        |> DateTime.add(n * 24 * 60 * 60, :second)
        |> DateTime.truncate(:second)

    defp list_credit_transactions(account_id) do
      Repo.all(
        from c in CreditTransaction, where: c.account_id == ^account_id, order_by: c.expires_at
      )
    end

    defp past_or_now?(nil), do: true
    defp past_or_now?(dt), do: DateTime.compare(dt, DateTime.utc_now()) != :gt
    defp future?(nil), do: false
    defp future?(dt), do: DateTime.compare(dt, DateTime.utc_now()) == :gt
  end
end
