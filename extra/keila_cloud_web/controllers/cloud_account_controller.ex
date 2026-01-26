require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAccountController do
    use KeilaWeb, :controller
    import Phoenix.LiveView.Controller

    def onboarding(conn, _) do
      live_render(conn, KeilaWeb.CloudAccountOnboardingLive,
        session: %{
          "current_account" => conn.assigns.current_account,
          "current_user" => conn.assigns.current_user,
          "locale" => Gettext.get_locale()
        }
      )
    end

    def await_subscription(conn, _) do
      live_render(conn, KeilaWeb.CloudAwaitSubscriptionLive,
        session: %{"current_user" => conn.assigns.current_user, "locale" => Gettext.get_locale()}
      )
    end

    def delete_subscription(conn, _) do
      account = conn.assigns.current_account

      case KeilaCloud.Billing.delete_account_subscription(account.id) do
        :ok ->
          conn
          |> redirect(to: Routes.account_path(conn, :edit))

        {:error, :subscription_active} ->
          conn
          |> put_flash(:error, dgettext("cloud", "Subscription still active"))
          |> redirect(to: Routes.account_path(conn, :edit))
      end
    end
  end
end
