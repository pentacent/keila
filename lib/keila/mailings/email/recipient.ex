alias Swoosh.Email.Recipient

alias Keila.Mailings.Campaign

defimpl Recipient, for: Campaign do
  @doc """
  You can reply to campaigns. Format _reply to_-fields from campaigns.
  """
  def format(%Campaign{sender: value}), do: Recipient.format(value)
end

alias Keila.Contacts.Contact

defimpl Recipient, for: Contact do
  def format(%Contact{email: address} = value) do
    Recipient.format({
      "#{value.first_name} #{value.last_name}",
      address
    })
  end
end

alias Keila.Mailings.Recipient, as: KeilaRecipient

defimpl Recipient, for: KeilaRecipient do
  def format(%KeilaRecipient{contact: value}), do: Recipient.format(value)
end

alias Keila.Mailings.Sender

defimpl Recipient, for: Sender do
  @doc """
  Format sender without _reply to_.
  """
  def format(%Sender{from_name: name, from_email: address}) do
    Recipient.format({
      name,
      address
    })
  end
end
