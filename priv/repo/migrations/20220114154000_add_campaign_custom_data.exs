defmodule Keila.Repo.Migrations.AddCampaignCustomData do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :data, :jsonb
    end
  end
end
