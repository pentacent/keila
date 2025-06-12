defmodule Keila.Repo.Migrations.AddAccountData do
  use Ecto.Migration
  require Keila

  Keila.if_cloud do
    Code.ensure_loaded!(KeilaCloud.Migrations.AddAccountData)
    defdelegate change(), to: KeilaCloud.Migrations.AddAccountData
  else
    def change do
      :ok
    end
  end
end
