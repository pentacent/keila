defmodule Keila.Repo.Migrations.AddContactsFormAttrs do
  use Ecto.Migration

  def change do
    create table("contacts_form_attrs") do
      add :attrs, :jsonb

      add :form_id, references("contacts_forms", on_delete: :delete_all)
      add :expires_at, :utc_datetime
      timestamps()
    end

    create constraint("contacts_form_attrs", :max_data_size,
             check: "pg_column_size(attrs) <= 8000"
           )
  end
end
