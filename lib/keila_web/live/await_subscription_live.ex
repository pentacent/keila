defmodule KeilaWeb.AwaitSubscriptionLive do
  use KeilaWeb, :live_view
  alias Keila.{Accounts, Billing}

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    account = Accounts.get_user_account(current_user.id)
    credits = Accounts.get_credits(account.id)

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:account, account)
      |> assign(:credits, credits)
      |> schedule_update()

    subscription = Billing.get_account_subscription(account.id)
    credits = Accounts.get_credits(account.id)

    if subscription && elem(credits, 0) > 0 do
      {:ok, redirect(socket, to: Routes.account_path(socket, :edit))}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.AccountView, "await_subscription_live.html", assigns)
  end

  @impl true
  def handle_info(:update, socket) do
    account_id = socket.assigns.account.id
    subscription = Billing.get_account_subscription(account_id)
    credits = Accounts.get_credits(account_id)

    if subscription && credits != socket.assigns.credits do
      {:noreply, redirect(socket, to: Routes.account_path(socket, :edit))}
    else
      {:noreply, schedule_update(socket)}
    end
  end

  defp schedule_update(socket) do
    if connected?(socket) do
      Process.send_after(self(), :update, 1000)
    end

    socket
  end
end
