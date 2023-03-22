defmodule Keila.Repo.Migrations.AddCampaignJsonBody do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :json_body, :json
    end
  end
end
