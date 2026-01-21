require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudPaddleWebhookController do
    require Keila
    use KeilaWeb, :controller

    alias KeilaCloud.Billing

    plug :authorize
    plug :put_resource

    @spec webhook(Plug.Conn.t(), map()) :: Plug.Conn.t()
    def webhook(conn, params = %{"alert_name" => "subscription_created"}) do
      params = parse_params(params)

      account_id = account_id(conn)

      case Billing.create_or_update_subscription(account_id, params, false) do
        {:ok, _} ->
          KeilaCloud.Accounts.handle_subscription_created(account_id)

          conn |> send_resp(200, "") |> halt()

        _other ->
          conn |> send_resp(400, "") |> halt()
      end
    end

    def webhook(conn, params = %{"alert_name" => "subscription_updated"}) do
      params = parse_params(params)
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
      params = parse_params(params)

      case Billing.create_or_update_subscription(account_id(conn), params, true) do
        {:ok, _} -> conn |> send_resp(200, "") |> halt()
        _other -> conn |> send_resp(400, "") |> halt()
      end
    end

    def webhook(conn, params = %{"alert_name" => "subscription_payment_failed"}) do
      params = parse_params(params)
      subscription = Billing.get_account_subscription(account_id(conn))

      case Billing.update_subscription(subscription.id, params, false) do
        {:ok, _} -> conn |> send_resp(200, "") |> halt()
        _other -> conn |> send_resp(400, "") |> halt()
      end
    end

    def webhook(conn, _params) do
      conn |> send_resp(404, "") |> halt()
    end

    @param_fields %{
      "cancel_url" => {:cancel_url, :string},
      "update_url" => {:update_url, :string},
      "user_id" => {:paddle_user_id, :string},
      "subscription_id" => {:paddle_subscription_id, :string},
      "subscription_plan_id" => {:paddle_plan_id, :string},
      "status" => {:status, :atom},
      "next_bill_date" => {:next_billed_on, :string}
    }

    defp parse_params(params) do
      Enum.reduce(params, [], fn {key, value}, acc ->
        case Map.get(@param_fields, key) do
          {field, :string} -> [{field, value} | acc]
          {field, :atom} -> [{field, String.to_existing_atom(value)} | acc]
          nil -> acc
        end
      end)
      |> Enum.into(%{})
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
end
