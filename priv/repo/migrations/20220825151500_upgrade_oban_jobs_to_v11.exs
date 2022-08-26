defmodule Keila.Repo.Migrations.UpgradeObanJobsToV11 do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 11)
  end

  def down do
    Oban.Migrations.down(version: 11)
  end
end
