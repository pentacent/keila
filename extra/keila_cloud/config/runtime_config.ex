require Keila

Keila.if_cloud do
  defmodule KeilaCloud.RuntimeConfig do
    defmacro __using__(_opts) do
      quote do
        updated_oban_plugins =
          update_in(
            Application.get_env(:keila, Oban)[:plugins],
            [
              Access.filter(&match?({Oban.Plugins.Cron, _}, &1)),
              Access.elem(1),
              :crontab
            ],
            &[{"0 */5 * * *", KeilaCloud.Workers.SenderDomainVerificationCronWorker} | &1]
          )

        config :keila, Oban, queues: [domain_verification: 10], plugins: updated_oban_plugins

        config :keila, Keila.Billing,
          enabled: System.get_env("ENABLE_BILLING") in [1, "1", "true", "TRUE"]

        paddle_vendor = System.get_env("PADDLE_VENDOR")

        if paddle_vendor not in [nil, ""],
          do: config(:keila, Keila.Billing, paddle_vendor: paddle_vendor)

        paddle_environment = System.get_env("PADDLE_ENVIRONMENT")

        if paddle_environment not in [nil, ""],
          do: config(:keila, Keila.Billing, paddle_environment: paddle_environment)

        config(:keila, KeilaCloud.Mailings.SendWithKeila.Mx2,
          access_key_id: System.get_env("SWK_SES_ACCESS_KEY_ID"),
          secret_access_key: System.get_env("SWK_SES_SECRET_ACCESS_KEY"),
          region: System.get_env("SWK_SES_REGION"),
          dkim_private_key: System.get_env("SWK_SES_DKIM_PRIVATE_KEY")
        )
      end
    end
  end
end
