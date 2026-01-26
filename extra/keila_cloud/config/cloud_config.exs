import Config

adapters = read_config(:keila)[Keila.Mailings.SenderAdapters][:adapters]

config :keila, Keila.Mailings.SenderAdapters,
  adapters: [
    KeilaCloud.Mailings.SendWithKeila | adapters
  ]

config :keila, KeilaCloud.Billing,
  # Disable subscriptions by default
  enabled: false,
  paddle_vendor: "2518",
  paddle_environment: "sandbox"
