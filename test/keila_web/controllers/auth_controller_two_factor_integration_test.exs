defmodule KeilaWeb.AuthControllerTwoFactorIntegrationTest do
  use KeilaWeb.ConnCase
  alias Keila.Auth

  @password "BatteryHorseStaple"

  describe "login with 2FA enabled" do
    @tag :auth_controller_2fa
    test "redirects to 2FA challenge when user has 2FA enabled", %{conn: conn} do
      # Create user and enable 2FA
      {_root, user} = with_seed()
      {:ok, user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      # Attempt to login with correct credentials
      login_params = %{email: user.email, password: @password}
      conn = post(conn, Routes.auth_path(conn, :post_login), user: login_params)
      
      # Should redirect to 2FA challenge, not log in directly
      assert redirected_to(conn, 302) == Routes.two_factor_path(conn, :challenge)
      assert get_session(conn, :pending_2fa_user_id) == user_with_2fa.id
      refute get_session(conn, :token)  # Should not be logged in yet
    end

    @tag :auth_controller_2fa  
    test "logs in directly when user has 2FA disabled", %{conn: conn} do
      # Create user with 2FA disabled (default)
      {_root, user} = with_seed()
      
      # Attempt to login with correct credentials
      login_params = %{email: user.email, password: @password}
      conn = post(conn, Routes.auth_path(conn, :post_login), user: login_params)
      
      # Should redirect to home page (successful login)
      assert redirected_to(conn, 302) == "/"
      assert get_session(conn, :token)  # Should be logged in
      refute get_session(conn, :pending_2fa_user_id)
    end

    @tag :auth_controller_2fa
    test "complete 2FA flow allows login", %{conn: conn} do
      # Create user and enable 2FA
      {_root, user} = with_seed()
      {:ok, user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      # Start login process
      login_params = %{email: user.email, password: @password}
      conn = post(conn, Routes.auth_path(conn, :post_login), user: login_params)
      assert redirected_to(conn, 302) == Routes.two_factor_path(conn, :challenge)
      
      # Get the 2FA code
      {:ok, code} = Auth.send_two_factor_code(user_with_2fa.id)
      
      # Complete 2FA verification
      conn = post(conn, Routes.two_factor_path(conn, :verify), two_factor: %{code: code})
      
      # Should now be logged in and redirected to home
      assert redirected_to(conn, 302) == "/"
      assert get_session(conn, :token)  # Should be logged in
      refute get_session(conn, :pending_2fa_user_id)
    end
  end
end
