defmodule Keila.Repo.Migrations.ChangeRecipientsToMessages do
  use Ecto.Migration

  def change do
    rename table("mailings_recipients"), to: table("messages")

    alter table("messages") do
      add :project_id, references("projects", on_delete: :delete_all)
      add :sender_id, references("mailings_senders", on_delete: :nilify_all)
      add :form_params_id, references("contacts_form_params", on_delete: :nilify_all)
      add :form_id, references("contacts_forms", on_delete: :nilify_all)

      add :recipient_email, :citext
      add :recipient_name, :string
      add :subject, :string
      add :html_body, :text
      add :text_body, :text

      add :status, :smallint, default: 0
      add :priority, :smallint, default: 0
    end

    create index(:messages, :contact_id)

    create index(:messages, [:sender_id, :priority, :inserted_at],
             where: "status = 1",
             name: :messages_ready_for_delivery
           )

    create index(:messages, [:status, :updated_at],
             where: "html_body is not null or text_body is not null",
             name: :messages_with_body
           )

    rename table("tracking_clicks"), :recipient_id, to: :message_id
    rename table("contacts_events"), :recipient_id, to: :message_id

    # This sets the status of messages based on their sent_at and failed_at timestamps.
    execute(
      "UPDATE messages SET status = 10 WHERE sent_at IS NOT NULL",
      ""
    )

    execute(
      "UPDATE messages SET status = -1 WHERE failed_at IS NOT NULL",
      ""
    )
  end
end
