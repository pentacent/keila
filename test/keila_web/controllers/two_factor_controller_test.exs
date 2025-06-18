defmodule KeilaWeb.TwoFactorControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Auth

  describe "setup" do
    @tag :two_factor_controller
    test "shows 2FA setup page", %{conn: conn} do
      conn = with_login(conn)
      
      conn = get(conn, Routes.two_factor_path(conn, :setup))
      assert html_response(conn, 200) =~ "Two-Factor Authentication"
    end
  end

  describe "enable" do
    @tag :two_factor_controller
    test "enables 2FA and shows backup codes", %{conn: conn} do
      conn = with_login(conn)
      
      conn = post(conn, Routes.two_factor_path(conn, :enable))
      
      assert html_response(conn, 200) =~ "Backup Codes"
      assert get_flash(conn, :info) =~ "Two-factor authentication has been enabled"
      
      # Verify user has 2FA enabled
      user = conn.assigns.current_user
      updated_user = Auth.get_user(user.id)
      assert updated_user.two_factor_enabled
    end
  end

  describe "disable" do
    @tag :two_factor_controller
    test "disables 2FA", %{conn: conn} do
      conn = with_login(conn)
      user = conn.assigns.current_user
      {:ok, _user_with_2fa} = Auth.enable_two_factor_auth(user.id)
      
      conn = post(conn, Routes.two_factor_path(conn, :disable))
      
      assert redirected_to(conn, 302) == Routes.two_factor_path(conn, :setup)
      assert get_flash(conn, :info) =~ "Two-factor authentication has been disabled"
      
      # Verify user has 2FA disabled
      updated_user = Auth.get_user(user.id)
      refute updated_user.two_factor_enabled
    end
  end

  describe "challenge" do
    @tag :two_factor_controller
    test "redirects to login when no pending 2FA", %{conn: conn} do
      conn = get(conn, Routes.two_factor_path(conn, :challenge))
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login)
    end
  end

  describe "verify" do
    @tag :two_factor_controller
    test "redirects to login when no pending 2FA", %{conn: conn} do
      conn = post(conn, Routes.two_factor_path(conn, :verify), two_factor: %{code: "123456"})
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login)
    end
  end

  describe "resend_code" do
    @tag :two_factor_controller
    test "redirects to login when no pending 2FA", %{conn: conn} do
      conn = post(conn, Routes.two_factor_path(conn, :resend_code))
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login)
    end
  end
end
