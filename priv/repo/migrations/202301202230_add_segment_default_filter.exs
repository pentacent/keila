defmodule Keila.Repo.Migrations.AddSegmentDefaultFilter do
  use Ecto.Migration

  def change do
    execute(&execute_up/0, &execute_down/0)
  end

  defp execute_up() do
    repo().query!("UPDATE contacts_segments SET filter='{}' WHERE filter IS NULL")

    alter table("contacts_segments") do
      modify :filter, :jsonb, default: %{}
    end
  end

  defp execute_down(), do: :ok
end
