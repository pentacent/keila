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
  end
end
