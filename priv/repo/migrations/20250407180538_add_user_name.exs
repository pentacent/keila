defmodule Keila.Repo.Migrations.AddUserName do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :given_name, :string, size: 64
      add :family_name, :string, size: 64
    end
  end
end
