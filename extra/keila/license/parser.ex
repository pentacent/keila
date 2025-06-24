defmodule Keila.License.Parser do
  alias Keila.License.Props

  @header "-----BEGIN LICENSE-----"
  @footer "-----END LICENSE-----"

  @spec decode(String.t()) ::
          {:ok, props :: %Props{}, signature :: String.t()} | {:error, String.t()}
  def decode(device) do
    with :ok <- assert_header(device),
         name <- read_line(device),
         email <- read_line(device),
         type <- read_line(device),
         {:ok, props} <- read_props(device),
         {:ok, signature_base16} <- read_signature(device),
         {:ok, signature} <- decode_signature(signature_base16),
         :ok <- assert_eof(device) do
      props = Map.merge(props, %{name: name, email: email, type: type})
      {:ok, props, signature}
    end
  end

  defp assert_header(device) do
    case read_line(device) do
      @header -> :ok
      :eof -> {:error, "Empty license"}
      _ -> {:error, "Missing header"}
    end
  end

  defp read_props(device) do
    do_read_props(device, read_line(device), %Props{})
  end

  defp do_read_props(_device, "", props), do: {:ok, props}

  defp do_read_props(device, current_line, props) when is_binary(current_line) do
    case String.split(current_line, ": ", parts: 2) do
      [key, value] ->
        case prop_key_atom(key) do
          {:ok, key} -> do_read_props(device, read_line(device), %{props | key => value})
          {:error, reason} -> {:error, reason}
        end

      _other ->
        {:error, "Invalid line: #{inspect(current_line)}"}
    end
  end

  defp do_read_props(_device, :eof, _props), do: {:error, "Unexpected EOF"}

  @valid_keys %Props{} |> Map.from_struct() |> Map.keys()
  defp prop_key_atom(key) when is_binary(key) do
    try do
      key =
        key
        |> String.downcase()
        |> String.replace(" ", "_")
        |> String.to_existing_atom()

      if key in @valid_keys do
        {:ok, key}
      else
        {:error, "Invalid atom key #{key}"}
      end
    rescue
      _e in ArgumentError ->
        {:error, "Invalid string key #{key}"}
    end
  end

  defp read_signature(device) do
    do_read_signature(device, read_line(device), "")
  end

  defp do_read_signature(_device, @footer, signature), do: {:ok, signature}

  defp do_read_signature(
         device,
         <<a::binary-size(8), " ", b::binary-size(8), " ", c::binary-size(8), " ",
           d::binary-size(8)>>,
         signature
       ) do
    do_read_signature(device, read_line(device), signature <> a <> b <> c <> d)
  end

  defp do_read_signature(_device, current_line, _),
    do: {:error, "Invalid line: #{inspect(current_line)}"}

  defp decode_signature(signature) do
    case Base.decode16(signature) do
      {:ok, signature} -> {:ok, signature}
      :error -> {:error, "Failed to decode signature"}
    end
  end

  defp assert_eof(device) do
    case IO.read(device, :line) do
      :eof -> :ok
      line -> {:error, "Expected EOF. Got: #{inspect(line)}"}
    end
  end

  defp read_line(device) do
    case IO.read(device, :line) do
      :eof -> ""
      line -> String.trim(line)
    end
  end
end
