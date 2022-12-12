defmodule Keila.Mailings.SenderAdapters.SMTP do
  use Keila.Mailings.SenderAdapters.Adapter

  @impl true
  def name, do: "smtp"

  @impl true
  def schema_fields do
    [
      smtp_relay: :string,
      smtp_username: :string,
      smtp_password: :string,
      smtp_tls: :boolean,
      smtp_port: :integer
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [:smtp_relay, :smtp_username, :smtp_password, :smtp_tls, :smtp_port])
    |> validate_required([:smtp_relay, :smtp_username, :smtp_password])
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.SMTP,
      relay: config.smtp_relay,
      username: config.smtp_username,
      password: config.smtp_password,
      auth: :always,
      port: config.smtp_port
    ]
    |> maybe_put_ssl_opt(config)
  end

  defp maybe_put_ssl_opt(opts, config) do
    if config.smtp_tls do
      Keyword.put(opts, :ssl, true)
    else
      opts
    end
  end
end
