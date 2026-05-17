defmodule Keila.Repo.Migrations.AddMessageForeignKeys do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:messages, :form_id, concurrently: true)
    create index(:messages, :form_params_id, concurrently: true)
    create index(:messages, :sender_id, concurrently: true)
  end
end
