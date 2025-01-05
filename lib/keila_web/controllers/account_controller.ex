defmodule KeilaWeb.AccountController do
  use KeilaWeb, :controller
  import Ecto.Changeset
  import Phoenix.LiveView.Controller
  alias Keila.{Auth, Accounts, Billing}

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _) do
    render_edit(conn, change(conn.assigns.current_user))
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, %{"user" => %{"password" => password}}) do
    params = %{password: password}

    case Auth.update_user_password(conn.assigns.current_user.id, params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, dgettext("auth", "New password saved."))
        |> render_edit(change(user))

      {:error, changeset} ->
        render_edit(conn, changeset)
    end
  end

  def post_edit(conn, %{"user" => %{"locale" => locale}}) do
    case Auth.set_user_locale(conn.assigns.current_user.id, locale) do
      {:ok, _user} ->
        conn
        |> redirect(to: Routes.account_path(conn, :edit))

      {:error, changeset} ->
        render_edit(conn, changeset)
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    case get_in(params, ["require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn)

      _ ->
        Keila.Admin.purge_user(conn.assigns.current_user.id)

        conn
        |> end_auth_session()
        |> redirect(to: Routes.auth_path(conn, :login))
    end
  end

  defp render_delete_confirmation(conn) do
    account =
      Accounts.get_user_account(conn.assigns.current_user.id)

    conn
    |> put_meta(:title, gettext("Confirm Account Deletion"))
    |> assign(:account, account)
    |> render("delete.html")
  end

  defp render_edit(conn, changeset) do
    account = Accounts.get_user_account(conn.assigns.current_user.id)
    credits = if account, do: Accounts.get_credits(account.id)
    subscription = if account, do: Billing.get_account_subscription(account.id)
    plans = if Billing.billing_enabled?(), do: Billing.get_plans()
    plan = if subscription, do: Billing.get_plan(subscription.paddle_plan_id)

    conn
    |> put_meta(:title, dgettext("auth", "Manage Account"))
    |> assign(:changeset, changeset)
    |> assign(:account, account)
    |> assign(:credits, credits)
    |> assign(:subscription, subscription)
    |> assign(:plans, plans)
    |> assign(:plan, plan)
    |> render("edit.html")
  end

  def await_subscription(conn, _) do
    live_render(conn, KeilaWeb.AwaitSubscriptionLive,
      session: %{"current_user" => conn.assigns.current_user, "locale" => Gettext.get_locale()}
    )
  end
end
