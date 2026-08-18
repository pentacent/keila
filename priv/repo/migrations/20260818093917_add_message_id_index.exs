defmodule Keila.Repo.Migrations.AddMessageReceiptIndex do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:messages, :receipt, concurrently: true)
  end
end
