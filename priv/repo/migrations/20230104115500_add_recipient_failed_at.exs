defmodule Keila.Repo.Migrations.AddRecipientFailedAt do
  use Ecto.Migration

  def change do
    alter table("mailings_recipients") do
      add :failed_at, :utc_datetime
    end
  end
end
