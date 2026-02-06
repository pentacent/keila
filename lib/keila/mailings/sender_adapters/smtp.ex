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
      smtp_tls_mode: :string,
      smtp_port: :integer,
      smtp_auth_method: :string,
      # deprecated:
      smtp_tls: :boolean
    ]
  end

  @impl true
  def changeset(changeset, params) do
    changeset
    |> cast(params, [
      :smtp_relay,
      :smtp_username,
      :smtp_password,
      :smtp_tls_mode,
      :smtp_port,
      :smtp_auth_method
    ])
    |> validate_required([:smtp_relay])
    |> validate_inclusion(:smtp_auth_method, ["password", "none", ""])
    |> maybe_require_smtp_auth()
  end

  defp maybe_require_smtp_auth(changeset) do
    case get_field(changeset, :smtp_auth_method) do
      "password" ->
        validate_required(changeset, [:smtp_username, :smtp_password])

      _ ->
        changeset
    end
  end

  @impl true
  def to_swoosh_config(%{config: config}) do
    [
      adapter: Swoosh.Adapters.SMTP,
      relay: config.smtp_relay,
      username: config.smtp_username,
      password: config.smtp_password,
      port: config.smtp_port
    ]
    |> maybe_put_auth(config)
    |> maybe_put_tls_opts(config)
  end

  defp maybe_put_tls_opts(opts, config) do
    cond do
      (config.smtp_tls && config.smtp_tls_mode in [nil, ""]) || config.smtp_tls_mode == "tls" ->
        opts
        |> Keyword.put(:ssl, true)
        |> Keyword.put(:sockopts, :tls_certificate_check.options(config.smtp_relay))

      config.smtp_tls_mode == "starttls" ->
        opts
        |> Keyword.put(:tls, :always)
        |> Keyword.put(:tls_options, :tls_certificate_check.options(config.smtp_relay))
        |> put_in([:tls_options, :versions], [:"tlsv1.2"])

      config.smtp_tls_mode == "none" ->
        opts
        |> Keyword.put(:tls, :never)
        |> Keyword.put(:ssl, false)

      true ->
        opts
    end
  end

  defp maybe_put_auth(opts, config) do
    case config.smtp_auth_method do
      "password" -> Keyword.put(opts, :auth, :always)
      "none" -> Keyword.put(opts, :auth, :never)
      _ -> opts
    end
  end
end
