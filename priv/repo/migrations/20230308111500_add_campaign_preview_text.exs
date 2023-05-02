defmodule Keila.Repo.Migrations.AddCampaignPreviewText do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :preview_text, :text
    end
  end
end
