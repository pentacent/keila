defmodule Keila.Repo.Migrations.AddRecipientQueuedAt do
  use Ecto.Migration

  def change do
    alter table("mailings_recipients") do
      add :queued_at, :utc_datetime
    end

    execute(&execute_up/0, fn -> :ok end)
  end

  defp execute_up() do
    repo().query!("UPDATE mailings_recipients SET queued_at=inserted_at")
  end
end
