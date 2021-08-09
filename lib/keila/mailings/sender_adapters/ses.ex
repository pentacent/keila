defmodule Keila.Mailings.SenderAdapters.SES do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "ses"

  @impl true
  def schema_fields do
    [
      ses_region: :string,
      ses_access_key: :string,
      ses_secret: :string,
      ses_configuration_set: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:ses_region, :ses_access_key, :ses_secret, :ses_configuration_set])
    |> validate_required([:ses_region, :ses_access_key, :ses_secret])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.AmazonSES,
      region: config.ses_region,
      access_key: config.ses_access_key,
      secret: config.ses_secret
    ]
  end

  @impl true
  def put_provider_options(email, %{config: config}) do
    case config.ses_configuration_set do
      nil ->
        email

      configuration_set ->
        Swoosh.Email.put_provider_option(email, :configuration_set, configuration_set)
    end
  end
end
