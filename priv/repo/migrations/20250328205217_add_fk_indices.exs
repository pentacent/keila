defmodule Keila.Repo.Migrations.AddFkIndices do
  use Ecto.Migration

  def change do
    create index(:accounts, :group_id)
    create index(:accounts_credit_transactions, :account_id)
    create index(:groups, :parent_id)
    create index(:user_groups, :user_id)
    create index(:user_groups, :group_id)
    create index(:user_group_roles, :user_group_id)
    create index(:user_group_roles, :role_id)
    create index(:roles, :parent_id)
    create index(:role_permissions, :role_id)
    create index(:role_permissions, :permission_id)
    create index(:tokens, :user_id)

    create index(:contacts, :project_id)
    create index(:contacts_forms, :project_id)
    create index(:contacts_forms, :sender_id)
    create index(:contacts_forms, :template_id)

    create index(:contacts_form_params, :form_id)

    create index(:contacts_segments, :project_id)
    create index(:files, :project_id)

    create index(:mailings_campaigns, :project_id)
    create index(:mailings_campaigns, :sender_id)
    create index(:mailings_campaigns, :template_id)
    create index(:mailings_campaigns, :segment_id)

    create index(:mailings_recipients, :campaign_id)
    create index(:mailings_recipients, :contact_id)
    create index(:mailings_recipients, :queued_at, where: "queued_at is NULL")

    create index(:mailings_senders, :project_id)
    create index(:mailings_senders, :shared_sender_id)

    create index(:projects, :group_id)

    create index(:templates, :project_id)

    create index(:tracking_clicks, :link_id)
    create index(:tracking_clicks, :recipient_id)

    create index(:tracking_links, :campaign_id)

    create index(:contacts_events, :recipient_id)
  end
end
