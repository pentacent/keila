defmodule Keila.Repo.Migrations.AddContactDoubleOptInTimestamp do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      add :double_opt_in_at, :utc_datetime
    end
  end
end
