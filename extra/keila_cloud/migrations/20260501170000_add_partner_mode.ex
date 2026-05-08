require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Migrations.AddPartnerMode do
    use Ecto.Migration

    def change do
      alter table("accounts") do
        add(:is_partner, :boolean, default: false, null: false)
        add(:partner_settings, :jsonb)
      end

      create(
        constraint("accounts", :max_partner_settings_size,
          check: "pg_column_size(partner_settings) <= 50000"
        )
      )
    end
  end
end
