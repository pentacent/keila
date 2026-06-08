defmodule Keila.Repo.Migrations.AddTemplateTypes do
  use Ecto.Migration

  def change do
    alter table(:templates) do
      add :mjml_body, :text
      add :html_body, :text
      add :text_body, :text
      add :type, :smallint, default: 20, null: false
      # remove :body
    end

    alter table(:mailings_campaigns) do
      add :mjml_content, :jsonb
      add :html_content, :jsonb
      add :text_content, :jsonb
    end
  end
end
