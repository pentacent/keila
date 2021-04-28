defmodule Keila.Mailings.SenderAdapters.Sendgrid do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "sendgrid"

  @impl true
  def schema_fields do
    [
      sendgrid_api_key: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:sendgrid_api_key])
    |> validate_required([:sendgrid_api_key])
  end

  @impl true
  def to_swoosh_config(%Sender{config: config}) do
    [
      adapter: Swoosh.Adapters.Sendgrid,
      api_key: config.sendgrid_api_key
    ]
  end
end
