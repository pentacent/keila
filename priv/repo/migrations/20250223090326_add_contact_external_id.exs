defmodule Keila.Repo.Migrations.AddContactExternalId do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      add :external_id, :string, size: 40
    end

    create unique_index("contacts", [:external_id, :project_id])
  end
end
