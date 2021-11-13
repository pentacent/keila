defmodule Keila.Repo.Migrations.AddContactCustomData do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      add :data, :jsonb
    end
  end
end
