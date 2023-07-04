defmodule Keila.Repo.Migrations.AddCampaignCustomData do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :data, :jsonb
    end

    create constraint("mailings_campaigns", :max_data_size,
             check: "pg_column_size(data) <= 32000"
           )

    create constraint("contacts", :max_data_size, check: "pg_column_size(data) <= 8000")
  end
end
