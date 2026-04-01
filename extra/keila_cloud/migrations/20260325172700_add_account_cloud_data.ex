require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Migrations.AddAccountCloudData do
    use Ecto.Migration

    def change do
      alter table("accounts") do
        add(:cloud_data, :jsonb)
      end

      create(
        constraint("accounts", :max_cloud_data_size, check: "pg_column_size(cloud_data) <= 5000")
      )
    end
  end
end
