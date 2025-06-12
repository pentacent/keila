require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Migrations.AddAccountData do
    use Ecto.Migration

    def change do
      alter table("accounts") do
        add(:contact_data, :jsonb)
        add(:onboarding_review_data, :jsonb)

        add(:status, :smallint, default: 0)
      end

      create(
        constraint("accounts", :max_contact_data_size,
          check: "pg_column_size(contact_data) <= 5000"
        )
      )

      create(
        constraint("accounts", :max_onboarding_review_data_size,
          check: "pg_column_size(onboarding_review_data) <= 5000"
        )
      )
    end
  end
end
