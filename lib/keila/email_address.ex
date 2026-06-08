defmodule Keila.EmailAddress do
  @moduledoc """
  Functions for parsing, normalizing and validating RFC 5322 email addresses and mailboxes.

  Based on the RFC, the following terms are used in this module:
  - "address" - an email address, e.g. `"hello@example.com"`
  - `mailbox` - an address, or an address combined with a name, e.g. `"Peter <hello@example.com>"`

  Parsing is based on the `:smtp_util` module from `gen_smtp`.
  """

  @doc """
  Returns `true` if `value` is a valid single email address.

  ## Examples

      iex> Keila.EmailAddress.valid?("brian@example.com")
      true

      iex> Keila.EmailAddress.valid?("invalid@example.com>")
      false
  """
  @spec valid?(term()) :: boolean()
  def valid?(address) when is_binary(address) do
    match?({:ok, [{:undefined, _}]}, :smtp_util.parse_rfc5322_addresses(address))
  end

  def valid?(_), do: false

  @doc """
  Returns `true` if `value` is a valid single mailbox.

  ## Examples

      iex> Keila.EmailAddress.valid_mailbox?("Peter <peter@example.com>")
      true

      iex> Keila.EmailAddress.valid_mailbox?("peter@example.com, lois@example.com")
      false
  """
  @spec valid_mailbox?(term()) :: boolean()
  def valid_mailbox?(value) when is_binary(value) do
    match?({:ok, [_mailbox]}, :smtp_util.parse_rfc5322_addresses(value))
  end

  def valid_mailbox?(_), do: false

  @doc """
  Ecto changeset validation to ensure the given `field` contains a single email address.

  ## Options

    * `:message` - the error message. Defaults to "is not a valid email address"
  """
  @spec validate_email(Ecto.Changeset.t(), atom(), keyword()) :: Ecto.Changeset.t()
  def validate_email(changeset, field, opts \\ []) do
    Ecto.Changeset.validate_change(changeset, field, :email, fn _, value ->
      if valid?(value) do
        []
      else
        message = Keyword.get(opts, :message, "is not a valid email address")
        [{field, message}]
      end
    end)
  end

  @doc """
  Ecto changeset validation to ensure the given `field` contains a list of
  mailbox strings (each string must be an email address, optionally with a display name).

  ## Options

    * `:message` - the error message. Defaults to "must be a list of valid email addresses"
  """
  @spec validate_mailbox_list(Ecto.Changeset.t(), atom(), keyword()) :: Ecto.Changeset.t()
  def validate_mailbox_list(changeset, field, opts \\ []) do
    Ecto.Changeset.validate_change(changeset, field, :mailbox_list, fn _, value ->
      if is_list(value) and Enum.all?(value, &valid_mailbox?/1) do
        []
      else
        message = Keyword.get(opts, :message, "must be a list of valid email addresses")
        [{field, message}]
      end
    end)
  end

  @doc """
  Normalizes a string or list of RFC 5322 mailbox strings into a flat list of
  canonical, single-mailbox RFC 5322 strings. Returns `:error` if any entry
  fails to parse.

  ## Examples

      iex> Keila.EmailAddress.to_mailbox_strings("Lois <lois@example.com>, peter@example.com")
      {:ok, ["Lois <lois@example.com>", "peter@example.com"]}
  """
  @spec to_mailbox_strings(String.t() | [String.t()] | nil) :: {:ok, [String.t()]} | :error
  def to_mailbox_strings(nil), do: {:ok, []}

  def to_mailbox_strings(value) do
    value
    |> parse_mailboxes()
    |> case do
      {:ok, mailboxes} -> {:ok, Enum.map(mailboxes, &to_mailbox_string/1)}
      :error -> :error
    end
  end

  @doc """
  Transforms a mailbox string, or a list of mailbox strings, or `nil` into a list of Swoosh recipients.

  ## Examples

      iex> Keila.EmailAddress.to_swoosh_recipients("Lois <lois@example.com>, peter@example.com")
      {:ok, [{"Lois", "lois@example.com"}, "peter@example.com"]}
  """
  def to_swoosh_recipients(nil), do: {:ok, []}

  def to_swoosh_recipients(value) do
    value
    |> parse_mailboxes()
    |> case do
      {:ok, mailboxes} -> {:ok, Enum.map(mailboxes, &to_swoosh_recipient/1)}
      :error -> :error
    end
  end

  defp parse_mailboxes(value) do
    value
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case parse(entry) do
        {:ok, mailboxes} -> {:cont, {:ok, acc ++ mailboxes}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp parse(entry) when is_binary(entry) do
    case :smtp_util.parse_rfc5322_addresses(entry) do
      {:ok, mailboxes} -> {:ok, mailboxes}
      _ -> :error
    end
  end

  defp parse(_), do: :error

  defp to_mailbox_string(mailbox),
    do: :smtp_util.combine_rfc822_addresses([mailbox]) |> to_string()

  defp to_swoosh_recipient({:undefined, address}), do: to_string(address)
  defp to_swoosh_recipient({name, address}), do: {to_string(name), to_string(address)}
end
