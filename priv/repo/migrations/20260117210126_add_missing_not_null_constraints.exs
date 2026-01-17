defmodule Keila.Repo.Migrations.AddMissingNotNullConstraints do
  use Ecto.Migration

  def change do
    alter table("projects") do
      modify :group_id, :bigint, null: false, from: {:bigint, null: true}
    end

    alter table("billing_subscriptions") do
      modify :account_id, :bigint, null: false, from: {:bigint, null: true}
    end

    alter table("contacts_events") do
      modify :contact_id, :bigint, null: false, from: {:bigint, null: true}
    end
  end
end
