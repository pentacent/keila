defmodule KeilaWeb.PaddleWebhookController do
  use KeilaWeb, :controller

  alias Keila.Billing

  plug :authorize
  plug :put_resource

  @spec webhook(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def webhook(conn, params = %{"alert_name" => "subscription_created"}) do
    params = subscription_params(params)

    case Billing.create_subscription(account_id(conn), params) do
      {:ok, _} -> conn |> send_resp(200, "") |> halt()
      _other -> conn |> send_resp(400, "") |> halt()
    end
  end

  def webhook(conn, params = %{"alert_name" => "subscription_updated"}) do
    params = subscription_params(params)
    subscription = Billing.get_account_subscription(account_id(conn))

    case Billing.update_subscription(subscription.id, params, false) do
      {:ok, _} -> conn |> send_resp(200, "") |> halt()
      _other -> conn |> send_resp(400, "") |> halt()
    end
  end

  def webhook(conn, _params = %{"alert_name" => "subscription_cancelled"}) do
    subscription = Billing.get_account_subscription(account_id(conn))

    case Billing.cancel_subscription(subscription.id) do
      {:ok, _} -> conn |> send_resp(200, "") |> halt()
      _other -> conn |> send_resp(400, "") |> halt()
    end
  end

  def webhook(conn, params = %{"alert_name" => "subscription_payment_succeeded"}) do
    params = payment_succeeded_params(params)
    subscription = Billing.get_account_subscription(account_id(conn))

    case Billing.update_subscription(subscription.id, params, true) do
      {:ok, _} -> conn |> send_resp(200, "") |> halt()
      _other -> conn |> send_resp(400, "") |> halt()
    end
  end

  def webhook(conn, params = %{"alert_name" => "subscription_payment_failed"}) do
    params = payment_failed_params(params)
    subscription = Billing.get_account_subscription(account_id(conn))

    case Billing.update_subscription(subscription.id, params, false) do
      {:ok, _} -> conn |> send_resp(200, "") |> halt()
      _other -> conn |> send_resp(400, "") |> halt()
    end
  end

  def webhook(conn, _params) do
    conn |> send_resp(404, "") |> halt()
  end

  defp subscription_params(params) do
    %{
      "cancel_url" => Map.fetch!(params, "cancel_url"),
      "update_url" => Map.fetch!(params, "update_url"),
      "paddle_user_id" => Map.fetch!(params, "user_id"),
      "paddle_subscription_id" => Map.fetch!(params, "subscription_id"),
      "paddle_plan_id" => Map.fetch!(params, "subscription_plan_id"),
      "status" => Map.fetch!(params, "status") |> String.to_existing_atom(),
      "next_billed_on" => Map.fetch!(params, "next_bill_date")
    }
  end

  defp payment_succeeded_params(params) do
    %{
      "paddle_user_id" => Map.fetch!(params, "user_id"),
      "paddle_subscription_id" => Map.fetch!(params, "subscription_id"),
      "paddle_plan_id" => Map.fetch!(params, "subscription_plan_id"),
      "status" => Map.fetch!(params, "status") |> String.to_existing_atom(),
      "next_billed_on" => Map.fetch!(params, "next_bill_date")
    }
  end

  defp payment_failed_params(params) do
    %{
      "paddle_user_id" => Map.fetch!(params, "user_id"),
      "paddle_subscription_id" => Map.fetch!(params, "subscription_id"),
      "paddle_plan_id" => Map.fetch!(params, "subscription_plan_id"),
      "status" => Map.fetch!(params, "status") |> String.to_existing_atom()
    }
  end

  defp account_id(conn), do: conn.assigns.account_id

  defp authorize(conn, _) do
    if Billing.Paddle.valid_signature?(conn.body_params) do
      conn
    else
      conn |> send_resp(403, "") |> halt()
    end
  end

  def put_resource(conn = %{body_params: params}, _) do
    passthrough = Map.get(params, "passthrough", "{}") |> Jason.decode!()

    assign(conn, :account_id, Map.fetch!(passthrough, "account_id"))
  end
end
