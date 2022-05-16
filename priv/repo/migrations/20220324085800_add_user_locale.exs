defmodule Keila.Repo.Migrations.AddUserLocale do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :locale, :string, size: 6
    end
  end
end
