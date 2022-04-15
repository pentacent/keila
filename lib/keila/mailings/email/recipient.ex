alias Keila.Contacts.Contact
alias Swoosh.Email.Recipient

defimpl Recipient, for: Contact do
  def format(%Contact{email: address} = value) do
    name = "#{value.first_name} #{value.last_name}"
    {name, address}
  end
end

alias Keila.Mailings.Sender

defimpl Recipient, for: Sender do

  @doc """
  Format sender without _reply to_.
  """
  def format(%Sender{from_name: name, from_email: address}) do
    {name, address}
  end
end

alias Keila.Mailings.Campaign

defimpl Recipient, for: Campaign do

  @doc """
  You can reply to campaigns. Format _reply to_-fields from campaigns.
  """
  def format(%Campaign{sender: %Sender{reply_to_name: name, reply_to_email: address}}) do
    {name, address}
  end
end
