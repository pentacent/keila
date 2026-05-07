defmodule Keila.Repo.Migrations.UpgradeObanJobsToV12 do
  use Ecto.Migration

  def up do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.up(prefix: prefix, version: 12)
  end

  def down do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.down(prefix: prefix, version: 12)
  end
end
