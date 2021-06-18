defmodule Keila.AccountsTest do
  use Keila.DataCase, async: true
  alias Keila.Accounts

  setup do
    root = insert!(:group)
    account_group = insert!(:group, parent: root)
    %{account_group: account_group, root: root}
  end

  @tag :accounts
  test "create and get account" do
    assert {:ok, account = %Accounts.Account{}} = Accounts.create_account()
    assert account == Accounts.get_account(account.id)
  end

  @tag :accounts
  test "set and get user account", %{account_group: group} do
    user = insert!(:user)
    %{id: account_id} = insert!(:account, group: group)
    assert nil == Accounts.get_user_account(user.id)
    assert :ok == Accounts.set_user_account(user.id, account_id)
    assert %{id: ^account_id} = Accounts.get_user_account(user.id)
  end

  @tag :accounts
  test "list users in account", %{account_group: group} do
    user1 = insert!(:user)
    user2 = insert!(:user)
    user3 = insert!(:user)
    account = insert!(:account, group: group)
    assert :ok == Accounts.set_user_account(user1.id, account.id)
    assert :ok == Accounts.set_user_account(user2.id, account.id)

    assert user1 in Accounts.list_account_users(account.id)
    assert user2 in Accounts.list_account_users(account.id)
    assert user3 not in Accounts.list_account_users(account.id)
  end

  @tag :accounts
  test "get acount from project", %{account_group: group} do
    user = insert!(:user)
    %{id: account_id} = insert!(:account, group: group)

    :ok = Accounts.set_user_account(user.id, account_id)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))

    assert %Accounts.Account{id: ^account_id} = Accounts.get_project_account(project.id)
  end

  @tag :accounts
  test "new users are automatically associated to a new account" do
    {:ok, user} = Keila.Auth.create_user(params(:user))
    assert %Accounts.Account{} = Accounts.get_user_account(user.id)
  end
end
