import Config
require Logger
:ok == Application.ensure_started(:logger)

exit_from_exception = fn exception, message ->
  Logger.error(exception.message)
  Logger.error(message)
  Logger.flush()
  System.halt(1)
end

maybe_to_int = fn
  string when string not in [nil, ""] -> String.to_integer(string)
  _ -> nil
end

put_if_not_empty = fn
  enumerable, key, value when value not in [nil, ""] -> put_in(enumerable, [key], value)
  enumerable, _, _ -> enumerable
end

if config_env() == :prod do
  # Database
  try do
    db_url = System.fetch_env!("DB_URL")
    ssl = System.get_env("DB_ENABLE_SSL") in [1, "1", "true", "TRUE"]
    ca_cert_pem = System.get_env("DB_CA_CERT")

    ca_cert_der =
      if ca_cert_pem not in [nil, ""] do
        ca_cert_pem
        |> :public_key.pem_decode()
        |> then(fn [pem_entry] -> :public_key.pem_entry_decode(pem_entry) end)
        |> then(fn x -> :public_key.der_encode(:Certificate, x) end)
      end

    ssl_opts =
      if ca_cert_der do
        [
          verify: :verify_peer,
          cacerts: [ca_cert_der],
          verify_fun: &:ssl_verify_hostname.verify_fun/3
        ]
      else
        []
      end

    config :keila, Keila.Repo,
      url: db_url,
      ssl: ssl,
      ssl_opts: ssl_opts
  rescue
    e ->
      exit_from_exception.(e, """
      You must provide the DB_URL environment variable in the format:
      postgres://user:password/database
      """)
  end

  # System Mailer
  try do
    mailer_type = System.get_env("MAILER_TYPE") || "smtp"

    config =
      case mailer_type do
        "smtp" ->
          host = System.fetch_env!("MAILER_SMTP_HOST")
          user = System.fetch_env!("MAILER_SMTP_USER")
          password = System.fetch_env!("MAILER_SMTP_PASSWORD")
          port = System.get_env("MAILER_SMTP_PORT") |> maybe_to_int.()

          [adapter: Swoosh.Adapters.SMTP, relay: host, username: user, password: password]
          |> put_if_not_empty.(:port, port)
      end

    config(:keila, Keila.Mailer, config)
  rescue
    e ->
      exit_from_exception.(e, """
      You must configure a mailer for system emails.

      Use the following environment variables:
      - MAILER_TYPE (defaults to "smtp")
      - MAILER_SMTP_HOST (required)
      - MAILER_SMTP_USER (required)
      - MAILER_SMTP_PASSWORD (required)
      - MAILER_SMTP_PORT (optional, defaults to 587)
      """)
  end

  # hCaptcha
  hcaptcha_site_key = System.get_env("HCAPTCHA_SITE_KEY")
  hcaptcha_secret_key = System.get_env("HCAPTCHA_SECRET_KEY")
  hcaptcha_url = System.get_env("HCAPTCHA_URL")

  if hcaptcha_site_key not in [nil, ""] and hcaptcha_secret_key not in [nil, ""] do
    config =
      [secret_key: hcaptcha_secret_key, site_key: hcaptcha_site_key]
      |> put_if_not_empty.(:url, hcaptcha_url)

    config :keila, KeilaWeb.Hcaptcha, config
  else
    Logger.warn("""
    hCaptcha not configured.
    Keila will fall back to using hCaptcha’s staging configuration.

    To configure hCaptcha, use the following environment variables:

    - HCAPTCHA_SITE_KEY
    - HCAPTCHA_SECRET_KEY
    - HCAPTCHA_URL (defaults to https://hcaptcha.com/siteverify)
    """)
  end

  # Secret Key Base
  try do
    secret_key_base = System.fetch_env!("SECRET_KEY_BASE")

    live_view_salt =
      :crypto.hash(:sha384, secret_key_base <> "live_view_salt") |> Base.url_encode64()

    config(:keila, KeilaWeb.Endpoint,
      secret_key_base: secret_key_base,
      live_view: [signing_salt: live_view_salt]
    )

    hashid_salt = :crypto.hash(:sha384, secret_key_base <> "hashid_salt") |> Base.url_encode64()
    config(:keila, Keila.Id, salt: hashid_salt)
  rescue
    e ->
      exit_from_exception.(e, """
      You must set SECRET_KEY_BASE.

      This should be a strong secret with a length
      of at least 64 characters.

      One way to create a strong secret is running the following command:
      head -c 48 /dev/urandom | base64
      """)
  end

  # Endpoint
  url_host = System.get_env("URL_HOST")
  url_port = System.get_env("URL_PORT") |> maybe_to_int.()
  url_schema = System.get_env("URL_SCHEMA")
  url_path = System.get_env("URL_PATH")

  url_schema =
    cond do
      url_schema not in [nil, ""] -> url_schema
      url_port == 443 -> "https"
      true -> "http"
    end

  if url_host not in [nil, ""] do
    config =
      [host: url_host, scheme: url_schema]
      |> put_if_not_empty.(:port, url_port)
      |> put_if_not_empty.(:path, url_path)

    config(:keila, KeilaWeb.Endpoint, url: config)
  else
    Logger.warn("""
    You have not configured the application URL. Defaulting to http://localhost.

    Use the following environment variables:
    - URL_HOST
    - URL_PORT (defaults to 80)
    - URL_SCHEMA (defaults to "https" for port 443, otherwise to "http")
    - URL_PATH (defaults to "/")
    """)
  end

  port = System.get_env("PORT") |> maybe_to_int.()

  if not is_nil(port) do
    config(:keila, KeilaWeb.Endpoint, http: [port: port])
  else
    Logger.info("""
    PORT environment variable unset. Running on port 4000.
    """)
  end

  # Deployment
  config :keila,
    # Disable registration of new users via the UI
    registration_disabled:
      System.get_env("DISABLE_REGISTRATION") not in [nil, "", "0", "false", "FALSE"],
    # Disable creation of Senders not using SharedSenders.
    sender_creation_disabled:
      System.get_env("DISABLE_SENDER_CREATION") not in [nil, "", "0", "false", "FALSE"]

  # Enable sending quotas
  config :keila, Keila.Accounts,
    credits_enabled: System.get_env("ENABLE_QUOTAS") in [1, "1", "true", "TRUE"]

  # Enable billing
  config :keila, Keila.Billing,
    enabled: System.get_env("ENABLE_BILLING") in [1, "1", "true", "TRUE"]

  paddle_vendor = System.get_env("PADDLE_VENDOR")

  if paddle_vendor not in [nil, ""],
    do: config(:keila, Keila.Billing, paddle_vendor: paddle_vendor)

  paddle_environment = System.get_env("PADDLE_ENVIRONMENT")

  if paddle_environment not in [nil, ""],
    do: config(:keila, Keila.Billing, paddle_environment: paddle_environment)

  # Precedence Bulk Header
  if System.get_env("DISABLE_PRECEDENCE_HEADER") in [1, "1", "true", "TRUE"] do
    config(:keila, Keila.Mailings, enable_precedence_header: false)
  end
end

if config_env() == :test do
  db_url = System.get_env("DB_URL")

  if db_url do
    db_url = db_url <> "#{System.get_env("MIX_TEST_PARTITION")}"
    config(:keila, Keila.Repo, url: db_url)
  end
end
