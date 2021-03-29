defmodule Keila.Repo.Migrations.FormTimestamps do
  use Ecto.Migration

  def change do
    alter table("contacts_forms") do
      timestamps(null: true)
    end

    execute(&execute_up/0, &execute_down/0)
  end

  defp execute_up() do
    repo().query!("UPDATE contacts_forms SET updated_at=NOW(), inserted_at=NOW()")

    alter table("contacts_forms") do
      modify :inserted_at, :naive_datetime, null: false
      modify :updated_at, :naive_datetime, null: false
    end
  end

  defp execute_down(), do: :ok
end
