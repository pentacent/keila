defmodule Keila.Mailings.Message do
  use Keila.Schema, prefix: "mr"
  alias Keila.Contacts.Contact
  alias Keila.Mailings.Campaign
  alias Keila.Mailings.Sender
  alias Keila.Projects.Project
  alias Keila.Contacts.Form
  alias Keila.Contacts.FormParams

  schema "messages" do
    field(:recipient_email, :string)
    field(:recipient_name, :string)
    field(:subject, :string)
    field(:html_body, :string)
    field(:text_body, :string)

    field(:priority, :integer, default: 0)
    field(:status, Ecto.Enum, values: [unrendered: 0, ready: 1, queued: 2, sent: 10, failed: -1])

    field(:receipt, :string)
    field(:queued_at, :utc_datetime)
    field(:sent_at, :utc_datetime)
    field(:opened_at, :utc_datetime)
    field(:clicked_at, :utc_datetime)
    field(:failed_at, :utc_datetime)
    field(:soft_bounce_received_at, :utc_datetime)
    field(:hard_bounce_received_at, :utc_datetime)
    field(:complaint_received_at, :utc_datetime)
    field(:unsubscribed_at, :utc_datetime)

    belongs_to(:project, Project, type: Project.Id)
    belongs_to(:contact, Contact, type: Contact.Id)
    belongs_to(:campaign, Campaign, type: Campaign.Id)
    belongs_to(:sender, Sender, type: Sender.Id)
    belongs_to(:form, Form, type: Form.Id)
    belongs_to(:form_params, FormParams, type: FormParams.Id)

    timestamps()
  end

  def changeset(message, params) do
    message
    |> cast(params, [
      :recipient_email,
      :recipient_name,
      :subject,
      :html_body,
      :text_body,
      :priority,
      :status,
      :receipt,
      :queued_at,
      :sent_at,
      :opened_at,
      :clicked_at,
      :failed_at,
      :soft_bounce_received_at,
      :hard_bounce_received_at,
      :complaint_received_at,
      :unsubscribed_at,
      :project_id,
      :contact_id,
      :campaign_id,
      :sender_id,
      :form_id,
      :form_params_id
    ])
  end
end
