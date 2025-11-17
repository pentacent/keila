require Keila

Keila.if_cloud do
  defmodule KeilaCloud.RuntimeConfig do
    defmacro __using__(_opts) do
      quote do
        config :keila, Keila.Billing,
          enabled: System.get_env("ENABLE_BILLING") in [1, "1", "true", "TRUE"]

        paddle_vendor = System.get_env("PADDLE_VENDOR")

        if paddle_vendor not in [nil, ""],
          do: config(:keila, Keila.Billing, paddle_vendor: paddle_vendor)

        paddle_environment = System.get_env("PADDLE_ENVIRONMENT")

        if paddle_environment not in [nil, ""],
          do: config(:keila, Keila.Billing, paddle_environment: paddle_environment)
      end
    end
  end
end
