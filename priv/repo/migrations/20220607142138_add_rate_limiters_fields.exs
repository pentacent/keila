defmodule Keila.Repo.Migrations.AddRateLimitersFields do
  use Ecto.Migration

  def change do
    alter table("mailings_senders") do
      add :rate_limit_per_hour, :int
      add :rate_limit_per_minute, :int
      add :rate_limit_per_second, :int
    end
  end
end
