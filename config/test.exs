import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# URL can be overwritten with the DB_URL environment variable.
config :keila, Keila.Repo,
  url:
    "ecto://postgres:postgres@localhost:5432/keila_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 60_000,
  timeout: 60_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :keila, KeilaWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure Swoosh
config :keila, Keila.Mailer, adapter: Swoosh.Adapters.Test

# Configure Argon2 for performance (not security)
config :argon2_elixir, t_cost: 1, m_cost: 8

# Disable Oban Queues
config :keila, Oban, queues: false, plugins: false

# Only use test and smtp Sender Adapters
config :keila, Keila.Mailings.SenderAdapters,
  adapters: [
    Keila.Mailings.SenderAdapters.SMTP,
    Keila.TestSenderAdapter
  ]
