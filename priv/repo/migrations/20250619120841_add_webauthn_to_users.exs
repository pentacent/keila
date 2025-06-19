defmodule Keila.Repo.Migrations.AddWebauthnToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :webauthn_credentials, {:array, :map}, default: []
    end
  end
end
