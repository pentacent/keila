defmodule Keila.Repo.Migrations.EmailsToCitext do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    alter table("users") do
      modify :email, :citext, null: false
    end

    alter table("contacts") do
      modify :email, :citext
    end
  end

  def down do
    alter table("users") do
      modify :email, :string, null: false
    end

    alter table("contacts") do
      modify :email, :string
    end
  end
end
