defmodule Keila.Repo.Migrations.AddFiles do
  use Ecto.Migration

  def change do
    create table("files", primary_key: false) do
      add :uuid, :binary, length: 16, primary_key: true
      add :filename, :string
      add :type, :string
      add :size, :integer
      add :sha256, :binary, length: 32
      add :adapter, :string, length: 16
      add :adapter_data, :jsonb

      add :project_id, references("projects", on_delete: :nilify_all)

      timestamps()
    end
  end
end
