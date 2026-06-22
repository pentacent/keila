defmodule Keila.EmailHeader do
  @moduledoc """
  Functions for validating custom email headers.

  Validation includes checks for control characters and certain reserved headers.
  """

  @max_header_count 30

  @reserved_header_names ~w(
    to from cc bcc sender reply-to subject date message-id return-path
    received dkim-signature domainkey-signature content-type
    content-transfer-encoding mime-version
  )

  # RFC 5322 ftext: printable ASCII excluding the colon (0x3A), no spaces/controls.
  @header_name_regex ~r/\A[\x21-\x39\x3B-\x7E]+\z/

  # C0 controls + DEL — most importantly CR/LF/NUL (header-injection vectors).
  @header_invalid_chars_regex ~r/[\x00-\x1F\x7F]/

  # RFC 5322 caps header lines at 998 bytes.
  @max_header_line_length 998

  @doc """
  Validates a single custom email header. Returns `:ok` or `{:error, message}`.
  """
  @spec validate(term(), term()) :: :ok | {:error, String.t()}
  def validate(name, value) when is_binary(name) and is_binary(value) do
    cond do
      String.downcase(name) in @reserved_header_names ->
        {:error, "uses a reserved name: #{inspect(name)}"}

      byte_size(name) + byte_size(value) + 2 > @max_header_line_length ->
        {:error, "exceeds the maximum line length for #{inspect(name)}"}

      not Regex.match?(@header_name_regex, name) ->
        {:error, "has an invalid name: #{inspect(name)}"}

      Regex.match?(@header_invalid_chars_regex, value) ->
        {:error, "has control characters in the value for #{inspect(name)}"}

      true ->
        :ok
    end
  end

  def validate(name, _value) when not is_binary(name),
    do: {:error, "has a non-string name: #{inspect(name)}"}

  def validate(_name, value),
    do: {:error, "has a non-string value: #{inspect(value)}"}

  @doc """
  Ecto changeset validation to ensure the given `field` contains a map of valid
  custom email headers (valid names/values, no reserved names).
  """
  @spec validate_headers(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_headers(changeset, field) do
    case Ecto.Changeset.get_field(changeset, field) do
      headers when is_map(headers) and map_size(headers) > @max_header_count ->
        Ecto.Changeset.add_error(
          changeset,
          field,
          "must not contain more than #{@max_header_count} headers"
        )

      headers when is_map(headers) ->
        Enum.reduce(headers, changeset, fn {name, value}, acc ->
          case validate(name, value) do
            :ok -> acc
            {:error, message} -> Ecto.Changeset.add_error(acc, field, message)
          end
        end)

      _ ->
        changeset
    end
  end
end
