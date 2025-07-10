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

  describe "challenge with WebAuthn" do
    @tag :two_factor_controller
    test "shows WebAuthn option when user has WebAuthn credentials", %{conn: conn} do
      user = insert!(:activated_user)

      # Add WebAuthn credential to user
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "test-credential-id",
          "public_key" => "test-public-key",
          "created_at" => "2023-01-01T00:00:00Z"
        }]
      })
      |> Keila.Repo.update!()

      # Set up pending 2FA session
      conn = conn
      |> init_test_session(%{})
      |> put_session(:pending_2fa_user_id, updated_user.id)

      conn = get(conn, Routes.two_factor_path(conn, :challenge))
      response = html_response(conn, 200)

      assert response =~ "Use Security Key"
      assert response =~ "tryWebAuthn()"
      assert response =~ updated_user.id
    end

    @tag :two_factor_controller
    test "shows email 2FA and WebAuthn options when both are available", %{conn: conn} do
      user = insert!(:activated_user)

      # Enable email 2FA
      {:ok, user_with_2fa} = Auth.enable_two_factor_auth(user.id)

      # Add WebAuthn credential
      updated_user = user_with_2fa
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "test-credential-id",
          "public_key" => "test-public-key",
          "created_at" => "2023-01-01T00:00:00Z"
        }]
      })
      |> Keila.Repo.update!()

      # Set up pending 2FA session
      conn = conn
      |> init_test_session(%{})
      |> put_session(:pending_2fa_user_id, updated_user.id)

      conn = get(conn, Routes.two_factor_path(conn, :challenge))
      response = html_response(conn, 200)

      # Should show both options
      assert response =~ "Enter the verification code sent to your email address"
      assert response =~ "Use Security Key"
      assert response =~ "Resend code"
      assert response =~ "You can use your security key, email verification code, or one of your backup codes"
    end

    @tag :two_factor_controller
    test "shows only WebAuthn option when email 2FA is disabled but WebAuthn is available", %{conn: conn} do
      user = insert!(:activated_user)

      # Add WebAuthn credential without enabling email 2FA
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "test-credential-id",
          "public_key" => "test-public-key",
          "created_at" => "2023-01-01T00:00:00Z"
        }]
      })
      |> Keila.Repo.update!()

      # Set up pending 2FA session
      conn = conn
      |> init_test_session(%{})
      |> put_session(:pending_2fa_user_id, updated_user.id)
      |> fetch_session()

      conn = get(conn, Routes.two_factor_path(conn, :challenge))
      response = html_response(conn, 200)

      # Should show WebAuthn only
      assert response =~ "Please use your security key to authenticate"
      assert response =~ "Use Security Key"
      refute response =~ "Enter the verification code"
      refute response =~ "Resend code"
    end

    @tag :two_factor_controller
    test "shows appropriate message when neither 2FA method is available", %{conn: conn} do
      user = insert!(:activated_user)

      # Set up pending 2FA session without any 2FA methods
      conn = conn
      |> init_test_session(%{})
      |> put_session(:pending_2fa_user_id, user.id)

      conn = get(conn, Routes.two_factor_path(conn, :challenge))
      response = html_response(conn, 200)

      assert response =~ "Please contact support for assistance"
      refute response =~ "Use Security Key"
      refute response =~ "Enter the verification code"
    end
  end

  describe "setup page with WebAuthn" do
    @tag :two_factor_controller
    test "shows WebAuthn registration option on setup page", %{conn: conn} do
      conn = with_login(conn)

      conn = get(conn, Routes.two_factor_path(conn, :setup))
      response = html_response(conn, 200)

      # Should show WebAuthn registration section
      assert response =~ "Security Keys"
      assert response =~ "Add Security Key"
    end

    @tag :two_factor_controller
    test "shows existing WebAuthn credentials on setup page", %{conn: conn} do
      conn = with_login(conn)
      user = conn.assigns.current_user

      # Add WebAuthn credential to user
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "test-credential-id",
          "public_key" => "test-public-key",
          "created_at" => "2023-01-01T00:00:00Z"
        }]
      })
      |> Keila.Repo.update!()

      # Update the connection to reflect the user changes
      conn = conn
      |> assign(:current_user, updated_user)

      conn = get(conn, Routes.two_factor_path(conn, :setup))
      response = html_response(conn, 200)

      # Should show existing credentials
      assert response =~ "test-credential-id"
      assert response =~ "Remove"
    end
  end
end
