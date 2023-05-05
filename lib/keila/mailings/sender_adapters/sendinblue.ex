defmodule Keila.Mailings.SenderAdapters.Sendinblue do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "sendinblue"

  @impl true
  def schema_fields do
    [
      sendinblue_api_key: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:sendinblue_api_key])
    |> validate_required([:sendinblue_api_key])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.Sendinblue,
      api_key: config.sendinblue_api_key
    ]
  end
end
