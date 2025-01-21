defmodule Keila.Repo.Migrations.AddParentAccount do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :parent_id, references("accounts", on_delete: :nilify_all)
    end
  end
end
