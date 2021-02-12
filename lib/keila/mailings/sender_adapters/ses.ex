defmodule Keila.Mailings.SenderAdapters.SES do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "ses"

  @impl true
  def schema_fields do
    [
      ses_region: :string,
      ses_access_key: :string,
      ses_secret: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:ses_region, :ses_access_key, :ses_secret])
    |> validate_required([:ses_region, :ses_access_key, :ses_secret])
  end

  @impl true
  def to_swoosh_config(struct) do
    [
      adapter: Swoosh.Adapters.SES,
      region: struct.ses_region,
      access_key: struct.ses_access_key,
      secret: struct.ses_secret
    ]
  end
end
