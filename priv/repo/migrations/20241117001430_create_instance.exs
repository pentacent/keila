defmodule Keila.Repo.Migrations.CreateInstance do
  use Ecto.Migration

  def change do
    create table("instance") do
      add :available_updates, :jsonb, default: "[]"
    end

    execute "CREATE UNIQUE INDEX instance_singleton ON instance ((true));", ""
    execute "INSERT INTO instance DEFAULT VALUES;", ""
  end
end
