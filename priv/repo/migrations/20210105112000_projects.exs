defmodule Keila.Repo.Migrations.Projects do
  use Ecto.Migration

  def change do
    create table("projects") do
      add :group_id, references("groups", on_delete: :delete_all), null: false
      add :name, :string
      timestamps()
    end
  end
end
