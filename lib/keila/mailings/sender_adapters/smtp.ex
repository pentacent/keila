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
  def to_swoosh_config(struct) do
    [
      adapter: Swoosh.Adapters.SMTP,
      relay: struct.smtp_relay,
      username: struct.smtp_username,
      password: struct.smtp_password,
      tls: if(struct.smtp_tls, do: :always),
      auth: :always,
      port: struct.smtp_port
    ]
  end
end
