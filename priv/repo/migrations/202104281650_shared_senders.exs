defmodule Keila.Repo.Migrations.SharedSenders do
  use Ecto.Migration

  def change do
    create table("mailings_shared_senders") do
      add :name, :string, null: false
      add :config, :jsonb

      timestamps()
    end

    alter table("mailings_senders") do
      add :shared_sender_id, references("mailings_shared_senders", on_delete: :delete_all)
    end
  end
end
