defmodule Keila.Mailer do
  use Swoosh.Mailer, otp_app: :keila

  @doc """
  Delivers an email using a given sender.
  """
  @spec deliver_with_sender(Swoosh.Email.t(), Sender.t() | SharedSender.t()) :: {:error, term()} | {:ok, term()}
  def deliver_with_sender(email, sender) do
    adapter = Keila.Mailings.SenderAdapters.get_adapter(sender.config.type)

    config =
      sender
      |> adapter.to_swoosh_config()
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)

    email
    |> adapter.put_provider_options(sender)
    |> deliver(config)
  end
end
