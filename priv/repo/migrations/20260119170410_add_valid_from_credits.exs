defmodule Keila.Repo.Migrations.AddValidFromCredits do
  use Ecto.Migration

  def change do
    alter table("accounts_credit_transactions") do
      add :valid_from, :utc_datetime
    end
  end
end
