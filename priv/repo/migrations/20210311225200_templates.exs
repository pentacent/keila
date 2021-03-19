defmodule Keila.Repo.Migrations.Templates do
  use Ecto.Migration

  def change do
    create table("templates") do
      add :project_id, references("projects", on_delete: :delete_all)

      add :name, :text
      add :body, :text
      add :styles, :text
      add :assigns, :jsonb

      timestamps()
    end

    alter table("mailings_campaigns") do
      add :template_id, references("templates", on_delete: :nilify_all)
    end
  end
end
