defmodule Keila.Repo.Migrations.Billing do
  use Ecto.Migration

  def change do
    create table("billing_subscriptions") do
      add :paddle_subscription_id, :string, null: false, unique: true
      add :paddle_plan_id, :string, null: false
      add :paddle_user_id, :string, null: false
      add :update_url, :string, null: false
      add :cancel_url, :string, null: false
      add :next_billed_on, :date, null: false
      add :status, :integer, null: false

      add :account_id, references("accounts", on_delete: :delete_all, null: false)

      timestamps()
    end

    create unique_index("billing_subscriptions", [:account_id])
    create unique_index("billing_subscriptions", [:paddle_subscription_id])
  end
end
