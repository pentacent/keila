defmodule Keila.Repo.Migrations.CreateRateLimiterState do
  use Ecto.Migration

  def change do
    create table(:rate_limiter_state) do
      add :data, :binary
      timestamps()
    end

    create constraint(:rate_limiter_state, :singleton, check: "id = 1")
  end
end
