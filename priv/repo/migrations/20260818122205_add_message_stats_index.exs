defmodule Keila.Repo.Migrations.AddMessageStatsIndex do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:messages, [:campaign_id],
             include: [
               :sent_at,
               :opened_at,
               :clicked_at,
               :failed_at,
               :unsubscribed_at,
               :hard_bounce_received_at,
               :complaint_received_at
             ],
             name: :messages_campaign_id_stats,
             concurrently: true
           )

    create index(:messages, [:campaign_id],
             where: "status = 0",
             name: :messages_unrendered_campaign_id,
             concurrently: true
           )

    execute(
      """
      ALTER TABLE messages SET (
        autovacuum_vacuum_scale_factor = 0,
        autovacuum_vacuum_threshold = 50000
      )
      """,
      """
      ALTER TABLE messages RESET (
        autovacuum_vacuum_scale_factor,
        autovacuum_vacuum_threshold
      )
      """
    )
  end
end
