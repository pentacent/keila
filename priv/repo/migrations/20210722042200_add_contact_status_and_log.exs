defmodule Keila.Repo.Migrations.AddContactSoftDelete do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      add :status, :smallint, default: 1, null: false
    end

    create table("contacts_events") do
      add :contact_id, references("contacts", on_delete: :delete_all, null: false)
      add :type, :smallint
      add :data, :jsonb
      timestamps(updated_at: false)
    end

    create index("contacts_events", [:contact_id])
    execute(&execute_up/0, fn -> :ok end)
  end

  defp execute_up() do
    repo().query!(
      "UPDATE contacts SET status=$1",
      [1]
    )
  end
end
