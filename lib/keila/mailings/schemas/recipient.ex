defmodule Keila.Mailings.Recipient do
  use Keila.Schema, prefix: "mr"
  alias Keila.Contacts.Contact
  alias Keila.Mailings.Campaign

  schema "mailings_recipients" do
    belongs_to(:contact, Contact, type: Contact.Id)
    belongs_to(:campaign, Campaign, type: Campaign.Id)

    field(:sent_at, :utc_datetime)
    timestamps()
  end
end
