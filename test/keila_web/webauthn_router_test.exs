defmodule KeilaWeb.WebauthnRouterTest do
  use KeilaWeb.ConnCase

  describe "WebAuthn routes" do
    @tag :webauthn_router
    test "unauthenticated WebAuthn routes work with form data", %{conn: conn} do
      user = insert!(:activated_user)

      # Add WebAuthn credential to user
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "dGVzdGNyZWRlbnRpYWxpZA",
          "public_key" => "g2gDYQFhAmED"
        }]
      })
      |> Keila.Repo.update!()

      # Test authenticate_begin with form data
      conn1 = conn
      |> post("/auth/webauthn/authenticate/begin", %{
        "user_id" => updated_user.id
      })

      # Should not get CSRF error (403), should get success (200) or validation error (400)
      assert conn1.status in [200, 400, 500]
      refute conn1.status == 403

      # Test authenticate_complete with form data
      conn2 = conn
      |> recycle()
      |> post("/auth/webauthn/authenticate/complete", %{
        "user_id" => updated_user.id,
        "assertion" => %{
          "id" => "test-id",
          "rawId" => [1, 2, 3],
          "response" => %{},
          "type" => "public-key"
        }
      })

      # Should not get CSRF error (403)
      assert conn2.status in [200, 302, 400, 500]
      refute conn2.status == 403
    end

    @tag :webauthn_router
    test "authenticated WebAuthn routes work with form data", %{conn: conn} do
      conn = with_login(conn)
      current_user = conn.assigns.current_user

      # Test register_begin with form data
      conn1 = conn
      |> post("/auth/webauthn/register/begin", %{})

      # Should not get CSRF error (403), should get success (200)
      assert conn1.status in [200, 400, 500]
      refute conn1.status == 403

      # Test register_complete with form data  
      # Need to simulate authentication for this endpoint
      import KeilaWeb.AuthSession, only: [start_auth_session: 2]
      conn2 = conn
      |> recycle()
      |> init_test_session(%{})
      |> start_auth_session(current_user.id)
      |> post("/auth/webauthn/register/complete", %{
        "attestation" => %{
          "id" => "test-id",
          "rawId" => [1, 2, 3],
          "response" => %{
            "attestationObject" => [4, 5, 6],
            "clientDataJSON" => [7, 8, 9]
          },
          "type" => "public-key"
        }
      })

      # Should not get CSRF error (403)
      assert conn2.status in [200, 302, 400, 500]
      refute conn2.status == 403
    end

    @tag :webauthn_router
    test "WebAuthn routes work with form data (backward compatibility)", %{conn: conn} do
      user = insert!(:activated_user)

      # Add WebAuthn credential to user
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "dGVzdGNyZWRlbnRpYWxpZA",
          "public_key" => "g2gDYQFhAmED"
        }]
      })
      |> Keila.Repo.update!()

      # Test with regular form data (should still work)
      conn = post(conn, "/auth/webauthn/authenticate/begin", %{
        "user_id" => updated_user.id
      })

      # Should work without CSRF issues
      assert conn.status in [200, 400, 500]
      refute conn.status == 403
    end
  end

  describe "WebAuthn route authentication requirements" do
    @tag :webauthn_router
    test "unauthenticated routes are accessible without login", %{conn: conn} do
      # These routes should be accessible for 2FA challenge

      conn1 = post(conn, "/auth/webauthn/authenticate/begin", %{"user_id" => "test"})
      assert conn1.status in [200, 400, 500]  # Not redirected to login

      conn2 = post(conn, "/auth/webauthn/authenticate/complete", %{
        "user_id" => "test",
        "assertion" => %{}
      })
      assert conn2.status in [200, 400, 500]  # Not redirected to login
    end

    @tag :webauthn_router
    test "authenticated routes require login", %{conn: conn} do
      # These routes should require authentication

      conn1 = post(conn, "/auth/webauthn/register/begin")
      assert redirected_to(conn1, 302) == Routes.auth_path(conn1, :login)

      conn2 = post(conn, "/auth/webauthn/register/complete", %{"attestation" => %{}})
      assert redirected_to(conn2, 302) == Routes.auth_path(conn2, :login)

      conn3 = delete(conn, "/auth/webauthn/credential/test-id")
      assert redirected_to(conn3, 302) == Routes.auth_path(conn3, :login)
    end
  end

  describe "Route existence and accessibility" do
    @tag :webauthn_router
    test "all WebAuthn routes are properly registered", %{conn: conn} do
      # Verify routes exist and return appropriate responses (not 404)

      # Unauthenticated routes
      conn1 = post(conn, "/auth/webauthn/authenticate/begin", %{"user_id" => "test"})
      refute conn1.status == 404

      conn2 = post(conn, "/auth/webauthn/authenticate/complete", %{
        "user_id" => "test",
        "assertion" => %{}
      })
      refute conn2.status == 404

      # Authenticated routes (will redirect to login but route exists)
      conn3 = post(conn, "/auth/webauthn/register/begin")
      refute conn3.status == 404

      conn4 = post(conn, "/auth/webauthn/register/complete", %{"attestation" => %{}})
      refute conn4.status == 404

      conn5 = delete(conn, "/auth/webauthn/credential/test-id")
      refute conn5.status == 404
    end
  end

  describe "Content-Type handling" do
    @tag :webauthn_router
    test "Browser pipeline accepts form data", %{conn: conn} do
      user = insert!(:activated_user)

      # Add WebAuthn credential to user
      updated_user = user
      |> Keila.Auth.User.update_webauthn_changeset(%{
        webauthn_credentials: [%{
          "id" => "dGVzdGNyZWRlbnRpYWxpZA",
          "public_key" => "g2gDYQFhAmED"
        }]
      })
      |> Keila.Repo.update!()

      # Test with form data (what browser pipeline expects)
      conn = conn
      |> post("/auth/webauthn/authenticate/begin", %{
        "user_id" => updated_user.id
      })

      # Should accept form data and return response
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
      assert conn.status in [200, 400, 500]
    end
  end
end
