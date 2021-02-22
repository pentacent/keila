defmodule Keila.Repo.Migrations.AddDeliverAtToCampaigns do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :scheduled_for, :utc_datetime
    end

    create index("mailings_campaigns", [:scheduled_for, :sent_at],
             where: "scheduled_for is not null and sent_at is null",
             name: :scheduled_campaigns
           )
  end
end
