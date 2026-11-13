defmodule Keila.Repo.Migrations.AddAuthEvents do
  use Ecto.Migration

  def change do
    create table("auth_events") do
      add :type, :string, null: false
      add :user_id, references("users", on_delete: :delete_all)
      add :actor_id, references("users", on_delete: :nilify_all)
      add :ip, :inet
      add :data, :map
      timestamps(updated_at: false)
    end

    create index("auth_events", [:user_id, :type, :inserted_at])
    create index("auth_events", [:ip, :type, :inserted_at])
    create index("auth_events", [:actor_id])
    create index("auth_events", [:inserted_at])
  end
end
