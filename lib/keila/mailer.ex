defmodule Keila.Mailer do
  use Swoosh.Mailer, otp_app: :keila
  alias Keila.Mailings.Sender
  alias Keila.Mailings.SharedSender

  @doc """
  Delivers an email using a given sender.
  """
  @spec deliver_with_sender(Swoosh.Email.t(), Sender.t() | SharedSender.t()) ::
          {:error, term()} | {:ok, term()}
  def deliver_with_sender(email, sender) do
    adapter = Keila.Mailings.SenderAdapters.get_adapter(sender.config.type)

    config =
      sender
      |> adapter.to_swoosh_config()
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)

    try do
      email
      |> put_from(sender, adapter)
      |> maybe_put_reply_to(sender, adapter)
      |> adapter.put_provider_options(sender)
      |> deliver(config)
    rescue
      e -> {:error, e}
    end
  end

  defp put_from(email, sender, adapter) do
    from = adapter.from(sender)
    Swoosh.Email.from(email, from)
  end

  defp maybe_put_reply_to(email, sender, adapter) do
    reply_to = adapter.reply_to(sender)

    if reply_to do
      Swoosh.Email.reply_to(email, reply_to)
    else
      email
    end
  end
end
