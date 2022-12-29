defmodule Keila.Tracking.Event do
  use Keila.Schema, prefix: "ce"
  alias Keila.Contacts.Contact
  alias Keila.Mailings.Recipient

  @events Enum.with_index([
            :create,
            :import,
            :subscribe,
            :unsubscribe,
            :double_opt_in,
            :open,
            :click,
            :soft_bounce,
            :hard_bounce,
            :complaint
          ])

  schema "contacts_events" do
    field(:type, Ecto.Enum, values: @events)
    field(:data, :map)

    belongs_to(:contact, Contact, type: Contact.Id)
    belongs_to(:recipient, Recipient, type: Recipient.Id)
    timestamps(updated_at: false)
  end

  @spec changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:contact_id, :recipient_id, :type, :data])
    |> validate_required([:contact_id, :type, :data])
  end
end
