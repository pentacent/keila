defmodule Keila.Repo.Migrations.AddFormDoubleOptInSettings do
  use Ecto.Migration

  def change do
    alter table("contacts_forms") do
      add :sender_id, references("mailings_senders", on_delete: :nilify_all)
      add :template_id, references("templates", on_delete: :nilify_all)
    end
  end
end
