defmodule Keila.Repo.Migrations.AddTwoFactorAuthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :two_factor_enabled, :boolean, default: false, null: false
      add :two_factor_backup_codes, {:array, :string}, default: []
    end
  end
end
