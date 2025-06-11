defmodule Keila.License do
  @moduledoc """
  This module provides functions for creating and validating Keila Cloud licenses.

  **Please note that this module is not licensed under the AGPL.**
  You are not allowed to modify this code or create distributions of it.
  For more information, refer to the extra/README.md file.
  """

  require Logger
  alias __MODULE__.Parser
  alias __MODULE__.Props

  @public_key "./extra/license.public.pem"
              |> File.read!()
              |> :public_key.pem_decode()
              |> hd()
              |> :public_key.pem_entry_decode()

  if System.get_env("LICENSE_PRIVATE_KEY") do
    @private_key System.get_env("LICENSE_PRIVATE_KEY")
                 |> :public_key.pem_decode()
                 |> hd()
                 |> :public_key.pem_entry_decode()

    @doc """
    Creates a new license and returns the license string.
    """
    def create(email, name, expires, type \\ "Keila Cloud") do
      content_data = %Props{
        name: name,
        email: email,
        expires: expires |> Date.to_iso8601(),
        type: type
      }

      signature = content_data |> to_msg() |> pretty_signature()

      """
      -----BEGIN LICENSE-----
      #{escape_string(name)}
      #{escape_string(email)}
      #{escape_string(type)}
      Expires: #{Date.to_iso8601(expires)}

      #{signature}
      -----END LICENSE-----
      """
    end

    defp escape_string(string) do
      string
      |> String.trim()
      |> String.replace("\n", "")
      |> then(fn string -> if String.valid?(string), do: string, else: "" end)
    end

    defp pretty_signature(msg) do
      :public_key.sign(msg, :sha256, @private_key)
      |> Base.encode16()
      |> String.graphemes()
      |> Enum.chunk_every(8)
      |> Enum.chunk_every(4)
      |> Enum.map(fn line ->
        Enum.join(line, " ")
      end)
      |> Enum.join("\n")
    end
  end

  @doc """
  Validates a license and returns `{:ok, props}` if the license is valid.
  """
  @spec validate(String.t()) :: {:ok, %Props{}} | {:error, String.t()}
  def validate(license) do
    StringIO.open(license, &do_validate/1)
    |> then(fn {:ok, result} -> result end)
  end

  defp do_validate(device) do
    with {:ok, props, signature} <- Parser.decode(device),
         :ok <- verify_signature(props, signature),
         {:ok, props} <- validate_expiration(props) do
      {:ok, props}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_signature(props, signature) do
    msg = to_msg(props)

    if :public_key.verify(msg, :sh256, signature, @public_key) do
      :ok
    else
      {:error, "Invalid signature"}
    end
  end

  defp validate_expiration(props) do
    today = Date.utc_today()
    expires = Date.from_iso8601!(props.expires)

    if today == expires || Date.after?(expires, today) do
      {:ok, %{props | expires: expires}}
    else
      {:error, "License expired!"}
    end
  end

  defp to_msg(props) do
    props
    |> Map.from_struct()
    |> Enum.sort()
    |> URI.encode_query()
  end
end
