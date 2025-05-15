defmodule Keila.Repo.Migrations.AddAccountsCreditTransactionsOnDelete do
  use Ecto.Migration

  def up do
    drop constraint(
           "accounts_credit_transactions",
           "accounts_credit_transactions_account_id_fkey"
         )

    alter table("accounts_credit_transactions") do
      modify :account_id, references("accounts", on_delete: :delete_all)
    end
  end

  def down do
  end
end
