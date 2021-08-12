defmodule Keila.Mailings.Recipient do
  use Keila.Schema, prefix: "mr"
  alias Keila.Contacts.Contact
  alias Keila.Mailings.Campaign

  schema "mailings_recipients" do
    belongs_to(:contact, Contact, type: Contact.Id)
    belongs_to(:campaign, Campaign, type: Campaign.Id)

    field(:receipt, :string)
    field(:sent_at, :utc_datetime)
    field(:opened_at, :utc_datetime)
    field(:clicked_at, :utc_datetime)
    timestamps()
  end
end
