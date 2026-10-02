defmodule Keila.Mailings.SenderAdapters.Mailgun do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "mailgun"

  @base_url "https://api.mailgun.net/v3"

  @impl true
  def schema_fields do
    [
      mailgun_api_key: :string,
      mailgun_domain: :string,
      mailgun_base_url: :string,
      mailgun_webhook_signing_key: :string
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [
      :mailgun_api_key,
      :mailgun_domain,
      :mailgun_base_url,
      :mailgun_webhook_signing_key
    ])
    |> validate_required([:mailgun_api_key, :mailgun_domain])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.Mailgun,
      api_key: config.mailgun_api_key,
      domain: config.mailgun_domain,
      base_url: config.mailgun_base_url || @base_url
    ]
  end

  @doc """
  Validates the signature of a Mailgun webhook.

  `signature` is the `"signature"` object of the webhook payload. Mailgun
  signs the concatenation of `timestamp` and `token` with HMAC-SHA256 using the
  account's *HTTP webhook signing key*.

  Returns `false` if no signing key is configured.
  """
  @spec valid_signature?(String.t() | nil, map()) :: boolean()
  def valid_signature?(signing_key, %{
        "timestamp" => timestamp,
        "token" => token,
        "signature" => signature
      })
      when is_binary(signing_key) and signing_key != "" and is_binary(token) and
             is_binary(signature) and (is_binary(timestamp) or is_integer(timestamp)) do
    expected =
      :crypto.mac(:hmac, :sha256, signing_key, to_string(timestamp) <> token)
      |> Base.encode16(case: :lower)

    Plug.Crypto.secure_compare(expected, String.downcase(signature))
  end

  def valid_signature?(_signing_key, _signature), do: false
end
