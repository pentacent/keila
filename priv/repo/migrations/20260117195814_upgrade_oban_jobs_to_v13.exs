defmodule Keila.Repo.Migrations.UpgradeObanJobsToV13 do
  use Ecto.Migration

  def up do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.up(prefix: prefix, version: 13)
  end

  def down do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.down(prefix: prefix, version: 13)
  end
end
