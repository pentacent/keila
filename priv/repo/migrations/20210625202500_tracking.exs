defmodule Keila.Repo.Migrations.Tracking do
  use Ecto.Migration

  def change do
    alter table("mailings_recipients") do
      add :clicked_at, :utc_datetime
      add :opened_at, :utc_datetime
    end

    create table("tracking_links") do
      add :url, :text, null: false
      add :campaign_id, references("mailings_campaigns", on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create unique_index("tracking_links", [:url, :campaign_id])

    create table("tracking_clicks") do
      add :link_id, references("tracking_links", on_delete: :delete_all), null: false
      add :recipient_id, references("mailings_recipients", on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end
  end
end
