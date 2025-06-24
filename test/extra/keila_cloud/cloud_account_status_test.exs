require Keila

Keila.if_cloud do
  defmodule KeilaCloud.AccountsTest.Credits do
    use Keila.DataCase, async: false
    alias Keila.Accounts

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
    test "update account status", %{account: account} do
      assert account.status == :default

      assert {:ok, %{status: :active}} =
               KeilaCloud.Accounts.update_account_status(account.id, :active)
    end

    @tag :accounts
    @tag :mailings
    @tag :contacts
    test "delivering campaigns requires an active account", %{user: user, account: account} do
      {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
      :ok = Keila.Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180.csv")
      sender = insert!(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)
      n = Repo.aggregate(Keila.Contacts.Contact, :count, :id)
      Accounts.add_credits(account.id, n, tomorrow())

      assert {:error, :account_not_active} = Keila.Mailings.deliver_campaign(campaign.id)

      KeilaCloud.Accounts.update_account_status(account.id, :active)
      assert :ok = Keila.Mailings.deliver_campaign(campaign.id)
      assert {^n, 0} = Accounts.get_credits(account.id)
    end

    @tag :accounts
    @tag :mailings
    @tag :contacts
    test "A campaign that failed to deliver when the account was not active is un-scheduled", %{
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

      n = Repo.aggregate(Keila.Contacts.Contact, :count, :id)
      Accounts.add_credits(account.id, n, tomorrow())

      assert {:error, :account_not_active} = Keila.Mailings.deliver_campaign(campaign.id)
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
  end
end
