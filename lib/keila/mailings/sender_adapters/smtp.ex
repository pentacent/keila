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
      tls: if(config.smtp_tls, do: :always),
      auth: :always,
      port: config.smtp_port
    ]
  end
end
