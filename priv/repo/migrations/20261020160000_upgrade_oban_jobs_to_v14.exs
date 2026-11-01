defmodule Keila.Repo.Migrations.UpgradeObanJobsToV14 do
  use Ecto.Migration

  def up do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.up(prefix: prefix, version: 14)
  end

  def down do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.down(prefix: prefix, version: 14)
  end
end
