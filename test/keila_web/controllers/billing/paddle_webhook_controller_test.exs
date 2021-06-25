defmodule KeilaWeb.PaddleWebhookControllerTest do
  use KeilaWeb.ConnCase, async: false
  alias Keila.Accounts
  alias Keila.Billing

  @plan Keila.Billing.Plans.all() |> Enum.random()

  setup do
    credits_enabled_before? =
      Application.get_env(:keila, Keila.Accounts, [])
      |> Keyword.get(:credits_enabled, false)

    set_credits_enabled(true)
    on_exit(fn -> set_credits_enabled(credits_enabled_before?) end)
  end

  defp set_credits_enabled(enable?) do
    config =
      Application.get_env(:keila, Keila.Accounts, [])
      |> Keyword.put(:credits_enabled, enable?)

    Application.put_env(:keila, Keila.Accounts, config)
  end

  @tag :paddle_webhook_controller
  test "subscription_created webhook", %{conn: conn} do
    account = get_account()
    data = get_data("subscription_created.unsigned.json", account.id, @plan.paddle_id)
    conn = post(conn, Routes.paddle_webhook_path(conn, :webhook), data)
    assert 200 == conn.status

    assert subscription = %Billing.Subscription{} = Billing.get_account_subscription(account.id)
    assert subscription.paddle_subscription_id == data["subscription_id"]
    assert {0, 0} == Accounts.get_credits(account.id)
  end

  @tag :paddle_webhook_controller
  test "subscription_updated webhook", %{conn: conn} do
    account = get_account()
    _subscription = get_subscription(conn, account.id, @plan.paddle_id)

    new_plan = Keila.Billing.Plans.all() |> Enum.find(&(&1.paddle_id != @plan.paddle_id))
    data = get_data("subscription_updated.json", account.id, new_plan.paddle_id)

    conn = post(conn, Routes.paddle_webhook_path(conn, :webhook), data)
    assert 200 == conn.status

    assert subscription = %Billing.Subscription{} = Billing.get_account_subscription(account.id)
    assert subscription.paddle_plan_id == new_plan.paddle_id
  end

  @tag :paddle_webhook_controller
  test "subscription_cancelled webhook", %{conn: conn} do
    account = get_account()
    _subscription = get_subscription(conn, account.id, @plan.paddle_id)

    data = get_data("subscription_cancelled.json", account.id, @plan.paddle_id)

    conn = post(conn, Routes.paddle_webhook_path(conn, :webhook), data)
    assert 200 == conn.status

    assert subscription = %Billing.Subscription{} = Billing.get_account_subscription(account.id)
    assert subscription.status == :deleted
  end

  @tag :paddle_webhook_controller
  test "payment_succeeded webhook", %{conn: conn} do
    account = get_account()
    _subscription = get_subscription(conn, account.id, @plan.paddle_id)

    data = get_data("payment_succeeded.json", account.id, @plan.paddle_id)

    conn = post(conn, Routes.paddle_webhook_path(conn, :webhook), data)
    assert 200 == conn.status

    assert {@plan.monthly_credits, @plan.monthly_credits} == Accounts.get_credits(account.id)
  end

  @tag :paddle_webhook_controller
  test "payment_failed webhook", %{conn: conn} do
    account = get_account()
    _subscription = get_subscription(conn, account.id, @plan.paddle_id)

    data = get_data("payment_failed.json", account.id, @plan.paddle_id)

    conn = post(conn, Routes.paddle_webhook_path(conn, :webhook), data)
    assert 200 == conn.status

    assert {0, 0} == Accounts.get_credits(account.id)
  end

  defp get_subscription(conn, account_id, plan_id) do
    data = get_data("subscription_created.unsigned.json", account_id, plan_id)
    post(conn, Routes.paddle_webhook_path(conn, :webhook), data)

    Billing.get_account_subscription(account_id)
  end

  defp get_account() do
    {_, user} = with_seed()
    Keila.Accounts.get_user_account(user.id)
  end

  defp get_data(filename, account_id, plan_id) do
    ("test/keila/billing/" <> filename)
    |> File.read!()
    |> Jason.decode!()
    |> Map.put("passthrough", Jason.encode!(%{"account_id" => account_id}))
    |> Map.put("subscription_plan_id", plan_id)
  end
end
