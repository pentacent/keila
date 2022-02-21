defmodule Keila.Repo.JsonField do
  use Ecto.Type

  def type, do: :map

  def cast(string) when is_binary(string) do
    case Jason.decode(string) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:ok, _} ->
        {:error, message: "must be a JSON object"}

      {:error, error = %Jason.DecodeError{}} ->
        message = Jason.DecodeError.message(error)
        {:error, message: message}
    end
  end

  def cast(map) when is_map(map), do: {:ok, map}

  def cast(_other), do: :error

  def dump(map) when is_map(map), do: {:ok, map}

  def dump(_), do: :error

  def load(map) when is_map(map), do: {:ok, map}
end
