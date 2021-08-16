defmodule Keila.Repo.Migrations.DefaultContactStatus do
  use Ecto.Migration

  def change do
    alter table("contacts") do
      modify :status, :smallint, default: 0, null: false
    end

    execute(&execute_up/0, fn -> :ok end)
  end

  defp execute_up() do
    repo().query!(
      "UPDATE contacts SET status=$1",
      [0]
    )
  end
end
