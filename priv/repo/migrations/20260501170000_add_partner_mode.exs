defmodule Keila.Repo.Migrations.AddPartnerMode do
  use Ecto.Migration
  require Keila

  Keila.if_cloud do
    Code.ensure_loaded!(KeilaCloud.Migrations.AddPartnerMode)
    defdelegate change(), to: KeilaCloud.Migrations.AddPartnerMode
  else
    def change do
      :ok
    end
  end
end
