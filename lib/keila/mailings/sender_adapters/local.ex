defmodule Keila.Mailings.SenderAdapters.Local do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "local"

  @impl true
  def schema_fields do
    []
  end

  @impl true
  def changeset(changeset, params) do
    changeset
  end

  @impl true
  def to_swoosh_config(struct) do
    [adapter: Swoosh.Adapters.Local]
  end
end
