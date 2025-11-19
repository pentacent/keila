import Config

adapters = read_config(:keila)[Keila.Mailings.SenderAdapters][:adapters]

config :keila, Keila.Mailings.SenderAdapters,
  adapters: [
    KeilaCloud.Mailings.SendWithKeila | adapters
  ]
