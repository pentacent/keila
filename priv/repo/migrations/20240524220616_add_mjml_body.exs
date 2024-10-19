defmodule Keila.Repo.Migrations.AddMjmlBody do
  use Ecto.Migration

  def change do
    alter table("mailings_campaigns") do
      add :mjml_body, :text
    end
  end
end
