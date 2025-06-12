defmodule Keila.AccountsTest.Credits do
  use Keila.DataCase, async: false
  alias Keila.Accounts
  require Keila

  setup do
    root_group = insert!(:group)
    account = insert!(:account, group: root_group)
    user = insert!(:user)
    Accounts.set_user_account(user.id, account.id)

    child_group = insert!(:group, parent: root_group)
    child_account = insert!(:account, group: child_group, parent_id: account.id)

    credits_enabled_before? =
      Application.get_env(:keila, Keila.Accounts, [])
      |> Keyword.get(:credits_enabled, false)

    set_credits_enabled(true)
    on_exit(fn -> set_credits_enabled(credits_enabled_before?) end)

    %{account: account, user: user, child_account: child_account}
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

  @tag :accounts
  test "account with parent account has credits of parent account", %{
    account: account,
    child_account: child_account
  } do
    Accounts.add_credits(account.id, 10, tomorrow())
    assert Accounts.get_available_credits(account.id) == 10
    assert Accounts.get_available_credits(child_account.id) == 10
    assert :ok = Accounts.consume_credits(child_account.id, 10)

    assert Accounts.get_available_credits(account.id) == 0
    assert Accounts.get_available_credits(child_account.id) == 0
  end

  @tag :accounts
  test "additional credits for child account can exist independently of parent account", %{
    account: account,
    child_account: child_account
  } do
    Accounts.add_credits(account.id, 10, tomorrow())
    Accounts.add_credits(child_account.id, 10, tomorrow())

    assert Accounts.get_available_credits(account.id) == 10
    assert Accounts.get_available_credits(child_account.id) == 20
    assert :ok = Accounts.consume_credits(child_account.id, 20)

    assert Accounts.get_available_credits(account.id) == 0
    assert Accounts.get_available_credits(child_account.id) == 0
  end

  @tag :accounts
  @tag :mailings
  @tag :contacts
  test "delivering campaigns requires and consumes credits", %{user: user, account: account} do
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    :ok = Keila.Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180.csv")
    sender = insert!(:mailings_sender, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    Keila.if_cloud do
      KeilaCloud.Accounts.update_account_status(account.id, :active)
    end

    assert {:error, :insufficient_credits} = Keila.Mailings.deliver_campaign(campaign.id)

    n = Repo.aggregate(Keila.Contacts.Contact, :count, :id)
    n_plus_1 = n + 1
    Accounts.add_credits(account.id, n_plus_1, tomorrow())
    assert :ok = Keila.Mailings.deliver_campaign(campaign.id)
    assert {^n_plus_1, 1} = Accounts.get_credits(account.id)
  end

  @tag :accounts
  @tag :mailings
  @tag :contacts
  test "A campaign that failed to deliver with insufficient credits is un-scheduled", %{
    user: user,
    account: account
  } do
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    :ok = Keila.Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180.csv")
    sender = insert!(:mailings_sender, project_id: project.id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        sender_id: sender.id,
        scheduled_for: now
      )

    Keila.if_cloud do
      KeilaCloud.Accounts.update_account_status(account.id, :active)
    end

    assert {:error, :insufficient_credits} = Keila.Mailings.deliver_campaign(campaign.id)
    assert %{scheduled_for: nil} = Keila.Mailings.get_campaign(campaign.id)
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
