defmodule Keila.Repo.Migrations.AddMessageRenderRetries do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :render_attempt, :integer, default: 0
    end
  end
end
