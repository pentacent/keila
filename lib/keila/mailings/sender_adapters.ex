defmodule Keila.Mailings.SenderAdapters do
  @moduledoc """
  Module for retrieving configured sender adapters and associated data.
  """

  @doc """
  Returns all configured sender adapter modules.
  """
  @spec adapters() :: list(Keila.Mailings.SenderAdapters.Adapter.t())
  def adapters do
    Application.get_env(:keila, __MODULE__, [])
    |> Keyword.get(:adapters)
  end

  @doc """
  Returns all configured shared sender adapter modules.
  """
  @spec shared_adapters() :: list(Keila.Mailings.SenderAdapters.Adapter.t())
  def shared_adapters do
    Application.get_env(:keila, __MODULE__, [])
    |> Keyword.get(:shared_adapters, [])
  end

  @doc """
  Returns the names of all configured sender adapters.
  """
  @spec adapter_names() :: list(String.t())
  def adapter_names do
    Enum.map(adapters(), fn a -> a.name end)
  end

  @doc """
  Returns the names of all configured shared sender adapters.
  """
  @spec shared_adapter_names() :: list(String.t())
  def shared_adapter_names do
    Enum.map(shared_adapters(), fn a -> a.name end)
  end

  @doc """
  Returns the configured sender adapter or shared sender adapter with the given `name`
  """
  @spec get_adapter(String.t()) :: Keila.Mailings.SenderAdapters.Adapter.t()
  def get_adapter(name) do
    Enum.find(adapters() ++ shared_adapters(), fn a -> a.name == name end)
  end

  @doc """
  Returns a combined list of `schema_fields` from all configured modules.
  """
  @spec schema_fields() :: keyword(atom())
  def schema_fields do
    Enum.map(adapters() ++ shared_adapters(), fn a -> a.schema_fields() end)
    |> List.flatten()
  end
end
