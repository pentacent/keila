defmodule PreluApi.Repo.Migrations.SubscriptionUpserts do
  use Ecto.Migration

  def up do
    alter table("billing_subscriptions") do
      modify :update_url, :string, null: true
      modify :cancel_url, :string, null: true
    end
  end

  def down do
    alter table("billing_subscriptions") do
      modify :update_url, :string, null: false
      modify :cancel_url, :string, null: false
    end
  end
end
