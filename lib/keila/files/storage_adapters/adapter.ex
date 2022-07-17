defmodule Keila.Files.StorageAdapters.Adapter do
  defmacro __using__(_options) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @type t :: module

  @doc """
  Returns the name of the sender adapter.
  """
  @callback name() :: String.t()

  @doc """
  Stores the file and returns a map that is stored as `adapter_data` in the
  database.

  The `metadata` map includes `:uuid`, `:sha256`, `type`, and `filename`
  properties.
  """
  @callback store(path :: String.t(), metadata :: map()) :: map()

  @doc """
  Deletes a file. Returns `:ok` on success or an error tuple.
  """
  @callback delete(File.t()) :: :ok | {:error, term}

  @doc """
  Returns the URL of a given file.
  """
  @callback get_url(File.t()) :: String.t()
end
