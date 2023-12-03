defmodule Keila.Repo.Migrations.AddContactsFormParams do
  use Ecto.Migration

  def change do
    create table("contacts_form_params") do
      add :params, :jsonb

      add :form_id, references("contacts_forms", on_delete: :delete_all)
      add :expires_at, :utc_datetime
      timestamps()
    end

    create constraint("contacts_form_params", :max_data_size,
             check: "pg_column_size(params) <= 8000"
           )
  end
end
