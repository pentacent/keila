defmodule Keila.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.up(prefix: prefix)
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    prefix = repo().config()[:migration_default_prefix] || "public"
    Oban.Migrations.down(version: 1, prefix: prefix)
  end
end
