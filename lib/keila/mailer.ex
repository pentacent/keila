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

    # Swoosh may return an error or send an exit signal for different types of
    # invalid recipient email addresses
    try do
      email
      |> put_from(sender, adapter)
      |> maybe_put_reply_to(sender, adapter)
      |> adapter.put_provider_options(sender)
      |> deliver(config)
    rescue
      e in MatchError ->
        if match?({:error, {_, :smtp_rfc5322_parse, _}}, e.term) do
          {:error, :invalid_email}
        else
          {:error, e}
        end

      e ->
        {:error, e}
    catch
      :exit, {:bad_label, _reason} ->
        {:error, :invalid_email}
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
