# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :keila,
  ecto_repos: [Keila.Repo]

# Configures the endpoint
config :keila, KeilaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "ipC9dsQLUBKuLmcrKzqB3m1M/Sw/53FcA1xQd1yUKdTSqjlBqL729evTWqqwd6zT",
  render_errors: [view: KeilaWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Keila.PubSub,
  live_view: [signing_salt: "kH+cT7XL"]

# Configure file uploads and serving of files
config :keila, Keila.Files, adapter: Keila.Files.StorageAdapters.Local

config :keila, Keila.Files.StorageAdapters.Local,
  serve: true,
  dir: "./uploads"

config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :keila, Keila.Id,
  alphabet: "abcdefghijkmnopqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ_",
  min_len: 8

config :keila, Keila.Mailings,
  # Minimum offset in seconds between current time and allowed scheduling time
  min_campaign_schedule_offset: 300,
  # Set Precedence: Bulk header
  enable_precedence_header: true

config :keila, Keila.Mailings.SenderAdapters,
  adapters: [
    Keila.Mailings.SenderAdapters.SMTP,
    Keila.Mailings.SenderAdapters.Sendgrid,
    Keila.Mailings.SenderAdapters.SES,
    Keila.Mailings.SenderAdapters.Mailgun,
    Keila.Mailings.SenderAdapters.Postmark
  ],
  shared_adapters: [
    Keila.Mailings.SenderAdapters.Shared.SES
  ]

config :keila, Keila.Accounts,
  # Disable sending quotas by default
  credits_enabled: false

config :keila, Keila.Billing,
  # Disable subscriptions by default
  enabled: false,
  paddle_vendor: "2518",
  paddle_environment: "sandbox"

# Staging configuration for hCaptcha
config :keila, KeilaWeb.Hcaptcha,
  secret_key: "0x0000000000000000000000000000000000000000",
  site_key: "10000000-ffff-ffff-ffff-000000000001",
  url: "https://hcaptcha.com/siteverify"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :keila, Oban,
  queues: [
    mailer: 50,
    periodic: 1
  ],
  repo: Keila.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 1800},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Keila.Mailings.DeliverScheduledCampaignsWorker}
     ]}
  ]

# Use Timezone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Add tsv MIME type
config :mime, :types, %{
  "text/tab-separated-values" => ["tsv"]
}

# Configure locales
config :keila, KeilaWeb.Gettext,
  default_locale: "en",
  locales: ["de", "en"]

config(:keila, Keila.Mailer, from_email: "keila@localhost")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
