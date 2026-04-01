defmodule Keila.Repo.Migrations.AddAccountCloudData do
  use Ecto.Migration
  require Keila

  Keila.if_cloud do
    Code.ensure_loaded!(KeilaCloud.Migrations.AddAccountCloudData)
    defdelegate change(), to: KeilaCloud.Migrations.AddAccountCloudData
  else
    def change do
      :ok
    end
  end
end
