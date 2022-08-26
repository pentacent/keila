defmodule Keila.Mailings.SenderAdapters.Shared.Local do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "shared_local"

  @impl true
  def schema_fields do
    []
  end

  @impl true
  def changeset(changeset, _params) do
    changeset
  end

  @impl true
  def to_swoosh_config(%{shared_sender: shared_sender}) do
    Keila.Mailings.SenderAdapters.Local.to_swoosh_config(shared_sender)
  end
end
