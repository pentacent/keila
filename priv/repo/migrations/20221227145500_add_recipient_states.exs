defmodule Keila.Repo.Migrations.AddRecipientStates do
  use Ecto.Migration

  def change do
    alter table("mailings_recipients") do
      add :soft_bounce_received_at, :utc_datetime
      add :hard_bounce_received_at, :utc_datetime
      add :complaint_received_at, :utc_datetime
      add :unsubscribed_at, :utc_datetime
    end

    alter table("contacts_events") do
      add :recipient_id, references("mailings_recipients", on_delete: :nilify_all)
    end
  end
end
