# TODO: This migration is still WIP

defmodule Keila.Repo.Migrations.ContactsMailings do
  use Ecto.Migration

  def change do
    create table("contacts") do
      add :project_id, references("projects", on_delete: :delete_all)

      add :first_name, :string
      add :last_name, :string
      # TODO address
      add :gender, :string
      add :email, :string
      add :verified_at, :utc_datetime

      timestamps()
    end

    create unique_index("contacts", [:email, :project_id])

    create table("mailings_senders") do
      add :project_id, references("projects", on_delete: :delete_all)

      add :name, :string, null: false
      add :from_email, :string, null: false
      add :from_name, :string
      add :reply_to_email, :string
      add :reply_to_name, :string
      add :config, :json

      timestamps()
    end

    create unique_index("mailings_senders", [:from_email])
    create unique_index("mailings_senders", [:name, :project_id])

    create table("mailings_forms") do
      add :project_id, references("projects", on_delete: :delete_all)

      add :name, :string, null: false
    end

    create table("mailings_campaigns") do
      add :project_id, references("projects", on_delete: :delete_all)
      add :sender_id, references("mailings_senders", on_delete: :nilify_all)

      add :subject, :string, null: false
      add :html_body, :text
      add :text_body, :text
    end

    create table("mailings_recipients") do
      add :campaign_id, references("mailings_campaigns", on_delete: :delete_all)
      add :contact_id, references("contacts", on_delete: :nilify_all)
    end
  end
end
