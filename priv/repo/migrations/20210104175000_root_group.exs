defmodule Keila.Repo.Migrations.RootGroup do
  use Ecto.Migration

  def change do
    create index("groups", ["(parent_id is NULL)"],
             using: "btree",
             where: "(parent_id IS NULL)",
             name: :root_group,
             unique: true
           )
  end
end
