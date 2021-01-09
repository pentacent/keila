defmodule Keila.Mailings.Sender.Config do
  use Ecto.Schema
  alias Ecto.Changeset
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :type, :string

    field :smtp_relay, :string
    field :smtp_username, :string
    field :smtp_password, :string
    field :smtp_tls, :boolean
    field :smtp_port, :integer

    field :ses_region, :string
    field :ses_access_key, :string
    field :ses_secret, :string

    field :sendgrid_api_key, :string
  end

  @spec changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type])
    |> validate_inclusion(:type, ["smtp", "ses", "sendgrid"])
    |> maybe_cast_smtp(params)
    |> maybe_cast_ses(params)
    |> maybe_cast_sendgrid(params)
  end

  defp maybe_cast_smtp(changeset, params) do
    if Changeset.get_field(changeset, :type) == "smtp" do
      changeset
      |> cast(params, [:smtp_relay, :smtp_username, :smtp_password, :smtp_tls, :smtp_port])
      |> validate_required([:smtp_relay, :smtp_username, :smtp_password])
    else
      changeset
    end
  end

  defp maybe_cast_ses(changeset, params) do
    if Changeset.get_field(changeset, :type) == "ses" do
      changeset
      |> cast(params, [:ses_region, :ses_access_key, :ses_secret])
      |> validate_required([:ses_region, :ses_access_key, :ses_secret])
    else
      changeset
    end
  end

  defp maybe_cast_sendgrid(changeset, params) do
    if Changeset.get_field(changeset, :type) == "sendgrid" do
      changeset
      |> cast(params, [:sendgrid_api_key])
      |> validate_required([:sendgrid_api_key])
    else
      changeset
    end
  end

  @doc """
  Converts the embedded schema to Keyword list for use with Swoosh.
  """
  @spec to_swoosh_config(t()) :: Keyword.t()
  def to_swoosh_config(struct) do
    case struct.type do
      "smtp" -> to_smtp_config(struct)
      "ses" -> to_ses_config(struct)
      "sendgrid" -> to_sendgrid_config(struct)
    end
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
  end

  defp to_smtp_config(struct) do
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

  defp to_ses_config(struct) do
    [
      adapter: Swoosh.Adapters.SES,
      region: struct.ses_region,
      access_key: struct.ses_access_key,
      secret: struct.ses_secret
    ]
  end

  defp to_sendgrid_config(struct) do
    [
      adapter: Swoosh.Adapters.Sendgrid,
      api_key: struct.sendgrid_api_key
    ]
  end
end
