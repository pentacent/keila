defmodule Keila.Mailings.SenderAdapters.Postmark do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "postmark"

  @impl true
  def schema_fields do
    [
      postmark_api_key: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:postmark_api_key])
    |> validate_required([:postmark_api_key])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.Postmark,
      api_key: config.postmark_api_key
    ]
  end
end
