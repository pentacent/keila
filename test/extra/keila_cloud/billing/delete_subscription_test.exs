require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.DeleteSubscriptionTest do
    use KeilaWeb.ConnCase, async: false
    alias KeilaCloud.Billing

    @plan KeilaCloud.Billing.Plans.all() |> Enum.random()

    describe "Billing.delete_account_subscription/1" do
      @tag :billing
      test "deletes subscription when status is :deleted" do
        account = get_account()
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :deleted)

        assert :ok = Billing.delete_account_subscription(account.id)
        assert nil == Billing.get_account_subscription(account.id)
      end

      @tag :billing
      test "returns error when subscription status is :active" do
        account = get_account()
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :active)

        assert {:error, :subscription_active} = Billing.delete_account_subscription(account.id)
        assert %Billing.Subscription{} = Billing.get_account_subscription(account.id)
      end

      @tag :billing
      test "returns error when subscription status is :paused" do
        account = get_account()
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :paused)

        assert {:error, :subscription_active} = Billing.delete_account_subscription(account.id)
        assert %Billing.Subscription{} = Billing.get_account_subscription(account.id)
      end

      @tag :billing
      test "returns error when subscription status is :past_due" do
        account = get_account()
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :past_due)

        assert {:error, :subscription_active} = Billing.delete_account_subscription(account.id)
        assert %Billing.Subscription{} = Billing.get_account_subscription(account.id)
      end
    end

    describe "CloudAccountController.delete_subscription/2" do
      @tag :billing
      test "deletes subscription and redirects when status is :deleted", %{conn: conn} do
        conn = with_login(conn)
        account = conn.assigns.current_account
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :deleted)

        conn = delete(conn, Routes.cloud_account_path(conn, :delete_subscription))

        assert redirected_to(conn, 302) == Routes.account_path(conn, :edit)
        assert nil == Billing.get_account_subscription(account.id)
      end

      @tag :billing
      test "shows error flash and redirects when subscription is active", %{conn: conn} do
        conn = with_login(conn)
        account = conn.assigns.current_account
        {:ok, _subscription} = create_subscription(account.id, @plan.paddle_id, :active)

        conn = delete(conn, Routes.cloud_account_path(conn, :delete_subscription))

        assert redirected_to(conn, 302) == Routes.account_path(conn, :edit)
        assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Subscription still active"
        assert %Billing.Subscription{} = Billing.get_account_subscription(account.id)
      end
    end

    defp get_account() do
      {_, user} = with_seed()
      Keila.Accounts.get_user_account(user.id)
    end

    defp create_subscription(account_id, plan_id, status) do
      Billing.create_subscription(account_id, %{
        paddle_subscription_id: "sub_#{System.unique_integer([:positive])}",
        paddle_user_id: "user_#{System.unique_integer([:positive])}",
        paddle_plan_id: plan_id,
        next_billed_on: Date.utc_today() |> Date.add(30),
        status: status
      })
    end
  end
end
