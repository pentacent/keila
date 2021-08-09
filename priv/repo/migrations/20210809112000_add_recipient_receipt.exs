defmodule Keila.Repo.Migrations.AddRecipeintReceipt do
  use Ecto.Migration

  def change do
    alter table("mailings_recipients") do
      add :receipt, :string, length: 32
    end
  end
end
