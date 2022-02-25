defmodule Keila.Repo.Migrations.AddRateLimitMinutes do
  use Ecto.Migration

  def change do
    alter table("mailings_senders") do
      add :rate_limit_minutes, :int
    end
  end
end
