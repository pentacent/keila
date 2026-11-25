defmodule Keila.Mailings.SenderAdapters.Cloudflare do
  @moduledoc """
  Sends campaigns through the Cloudflare Email Service REST API.

  The API token needs the `Email Sending: Edit` permission and the account ID is
  the Cloudflare account that owns the onboarded sending domain. The sender
  `from` address must be on a domain onboarded for Email Sending.

  Cloudflare also offers an SMTP submission endpoint, but only on port 465 with
  implicit TLS, which many hosts block. See
  `Keila.Mailings.SwooshAdapters.Cloudflare` for the delivery side.
  """

  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "cloudflare"

  @impl true
  def schema_fields do
    [
      cloudflare_account_id: :string,
      cloudflare_api_token: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:cloudflare_account_id, :cloudflare_api_token])
    |> validate_required([:cloudflare_account_id, :cloudflare_api_token])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Keila.Mailings.SwooshAdapters.Cloudflare,
      account_id: config.cloudflare_account_id,
      api_token: config.cloudflare_api_token
    ]
  end
end
