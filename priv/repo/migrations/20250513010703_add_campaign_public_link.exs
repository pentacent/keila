defmodule Keila.Repo.Migrations.AddCampaignPublicLink do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :public_link_enabled, :boolean, default: false
    end
  end
end
