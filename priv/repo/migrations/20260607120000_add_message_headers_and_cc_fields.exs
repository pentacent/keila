defmodule Keila.Repo.Migrations.AddMessageHeadersAndCcFields do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :cc, {:array, :string}, default: [], null: false
      add :bcc, {:array, :string}, default: [], null: false
    end
  end
end
