defmodule Keila.Repo.Migrations.DefaultContactStatus do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      modify :status, :smallint, default: 0, null: false
    end

    execute(&execute_up/0, fn -> :ok end)
  end

  defp execute_up() do
    prefix = repo().config()[:migration_default_prefix] || "public"
    repo().query!(
      "UPDATE #{prefix}.contacts SET status=$1",
      [0]
    )
  end
end
