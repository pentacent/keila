defmodule Keila.TestSenderAdapter do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "test"

  @impl true
  def schema_fields, do: []

  @impl true
  def changeset(changeset, _params), do: changeset

  @impl true
  def to_swoosh_config(_struct), do: []
end
