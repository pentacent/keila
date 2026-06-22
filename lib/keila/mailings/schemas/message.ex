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
    field(:cc, {:array, :string}, default: [])
    field(:bcc, {:array, :string}, default: [])
    field(:subject, :string)
    field(:html_body, :string)
    field(:text_body, :string)
    field(:headers, :map, default: %{})

    field(:priority, :integer, default: 100)
    field(:render_attempt, :integer, default: 0)
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

  def changeset(message \\ %__MODULE__{}, params) do
    message
    |> cast(params, [
      :recipient_email,
      :recipient_name,
      :cc,
      :bcc,
      :subject,
      :html_body,
      :text_body,
      :headers,
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
    |> validate_emails()
    |> validate_assocs_project()
  end

  defp validate_emails(changeset) do
    changeset
    |> Keila.EmailAddress.validate_email(:recipient_email)
    |> Keila.EmailAddress.validate_mailbox_list(:cc)
    |> Keila.EmailAddress.validate_mailbox_list(:bcc)
  end

  defp validate_assocs_project(changeset) do
    changeset
    |> validate_assoc_project(:contact, Contact)
    |> validate_assoc_project(:campaign, Campaign)
    |> validate_assoc_project(:sender, Sender)
    |> validate_assoc_project(:form, Form)
  end
end
