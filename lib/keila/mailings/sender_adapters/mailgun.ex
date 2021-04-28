defmodule Keila.Mailings.SenderAdapters.Mailgun do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "mailgun"

  @impl true
  def schema_fields do
    [
      mailgun_api_key: :string,
      mailgun_domain: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:mailgun_api_key, :mailgun_domain])
    |> validate_required([:mailgun_api_key, :mailgun_domain])
  end

  @impl true
  def to_swoosh_config(%Sender{config: config}) do
    [
      adapter: Swoosh.Adapters.Mailgun,
      api_key: config.mailgun_api_key,
      domain: config.mailgun_domain
    ]
  end
end
