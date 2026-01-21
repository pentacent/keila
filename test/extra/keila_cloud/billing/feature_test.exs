require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.FeatureTest do
    use Keila.DataCase, async: false
    alias Keila.Accounts
    alias KeilaCloud.Billing

    setup do
      {_root, user} = with_seed()

      {:ok, project} =
        Keila.Projects.create_project(user.id, %{name: "Foo Bar"})

      account = Keila.Accounts.get_project_account(project.id)

      billing_enabled? =
        Application.get_env(:keila, Billing, [])
        |> Keyword.get(:enabled)

      on_exit(fn ->
        enable_billing(billing_enabled?)
      end)

      %{project: project, account: account}
    end

    describe "feature_available? for :double_opt_in" do
      @describetag :billing
      test "is true if Billing is disabled", %{project: project} do
        enable_billing(false)

        assert Billing.feature_available?(project.id, :double_opt_in)
      end

      test "Requires credits when Billing is enabled", %{project: project, account: account} do
        enable_billing(true)

        assert {0, 0} = Accounts.get_credits(account.id)
        refute Billing.feature_available?(project.id, :double_opt_in)

        Accounts.add_credits(account.id, 1, in_one_hour())
        assert {1, 1} = Accounts.get_credits(account.id)
        assert Billing.feature_available?(project.id, :double_opt_in)
      end

      test "Is still true when Billing is enabled and credits have been spent", %{
        project: project,
        account: account
      } do
        enable_billing(true)
        Accounts.add_credits(account.id, 1, in_one_hour())
        Accounts.consume_credits(account.id, 1)

        assert {1, 0} = Accounts.get_credits(account.id)
        assert Billing.feature_available?(project.id, :double_opt_in)
      end
    end

    defp enable_billing(enable?) do
      billing_config =
        Application.get_env(:keila, Billing)
        |> Keyword.put(:enabled, enable?)

      Application.put_env(:keila, Billing, billing_config)

      accounts_config =
        Application.get_env(:keila, Accounts)
        |> Keyword.put(:credits_enabled, enable?)

      Application.put_env(:keila, Accounts, accounts_config)
    end

    defp in_one_hour(), do: DateTime.utc_now() |> DateTime.add(2, :day)
  end
end
