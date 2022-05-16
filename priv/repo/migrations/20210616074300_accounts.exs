defmodule Keila.Repo.Migrations.AccountsCredits do
  use Ecto.Migration

  def change do
    create table("accounts") do
      add :group_id, references("groups")

      timestamps()
    end

    create table("accounts_credit_transactions") do
      add :amount, :integer
      add :expires_at, :utc_datetime

      add :account_id, references("accounts")

      timestamps(updated_at: false)
    end

    execute(&execute_up/0, &execute_down/0)
  end

  defp execute_up() do
    repo().query!("SELECT id FROM users")
    |> Map.fetch!(:rows)
    |> Enum.map(fn [user_id] ->
      {:ok, account} = Keila.Accounts.create_account()
      Keila.Accounts.set_user_account(user_id, account.id)
    end)
  end

  defp execute_down() do
    root_group = Keila.Auth.root_group()
    {:ok, root_group_id} = Keila.Auth.Group.Id.decode(root_group.id)

    repo().query!(
      "UPDATE groups SET parent_id=$1 WHERE parent_id IN (SELECT group_id FROM accounts)",
      [root_group_id]
    )
  end
end
