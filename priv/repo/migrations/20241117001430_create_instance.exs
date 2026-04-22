defmodule Keila.Repo.Migrations.CreateInstance do
  use Ecto.Migration

  def change do
    create table("instance") do
      add :available_updates, :jsonb, default: "[]"
    end

    prefix = repo().config()[:migration_default_prefix] || "public"
    execute "CREATE UNIQUE INDEX instance_singleton ON #{prefix}.instance ((true));", ""
    execute "INSERT INTO #{prefix}.instance DEFAULT VALUES;", ""
  end
end
