defmodule Keila.Repo.Migrations.Segments do
  use Ecto.Migration

  def change do
    create table("contacts_segments") do
      add :project_id, references("projects", on_delete: :delete_all)
      add :name, :string
      add :filter, :jsonb

      timestamps()
    end

    alter table("mailings_campaigns") do
      add :segment_id, references("contacts_segments", on_delete: :nilify_all)
    end
  end
end
