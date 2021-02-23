defmodule KeilaWeb.AuthControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.{Repo, Auth}

  @password "BatteryHorseStaple"
  @sign_up_params %{"email" => "foo@bar.com", "password" => @password}
  @valid_hcaptcha "10000000-aaaa-bbbb-cccc-000000000001"

  setup do
    with_seed()
    :ok
  end

  describe "sign up form" do
    @tag :auth_controller
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :register))
      assert html_response(conn, 200) =~ "Register your Keila account now"
    end

    @tag :auth_controller
    test "allows registration with valid params and captcha", %{conn: conn} do
      conn =
        post(conn, Routes.auth_path(conn, :register),
          user: @sign_up_params,
          "h-captcha-response": @valid_hcaptcha
        )

      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_email_sent()
      assert {:ok, %{activated_at: nil}} = Auth.find_user_by_credentials(@sign_up_params)
    end

    @tag :auth_controller
    test "shows error with missing captcha", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :register), user: @sign_up_params)
      assert html_response(conn, 400) =~ ~r{Please complete the captcha.}
      assert_no_email_sent()
    end

    @tag :auth_controller
    test "shows error with invalid params", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :register))
      assert html_response(conn, 400) =~ "Register your Keila account now"

      params = %{user: %{}, "h-captcha-response": @valid_hcaptcha}
      conn = post(conn, Routes.auth_path(conn, :register), params)
      assert html_response(conn, 400) =~ "Register your Keila account now"

      params = %{user: %{"email" => "", "password" => ""}, "h-captcha-response": @valid_hcaptcha}
      conn = post(conn, Routes.auth_path(conn, :register), params)

      assert html_response(conn, 400) =~ "Register your Keila account now"

      params = %{
        user: Map.put(@sign_up_params, "email", ""),
        "h-captcha-response": @valid_hcaptcha
      }

      conn = post(conn, Routes.auth_path(conn, :register), params)

      assert html_response(conn, 400) =~ "Register your Keila account now"

      params = %{
        user: Map.put(@sign_up_params, "password", ""),
        "h-captcha-response": @valid_hcaptcha
      }

      conn = post(conn, Routes.auth_path(conn, :register), params)

      assert html_response(conn, 400) =~ "Register your Keila account now"

      params = %{
        user: Map.put(@sign_up_params, "password", "too-short"),
        "h-captcha-response": @valid_hcaptcha
      }

      conn = post(conn, Routes.auth_path(conn, :register), params)

      assert html_response(conn, 400) =~ "Register your Keila account now"
    end
  end

  @tag :auth_controller
  test "user is activated with activation link", %{conn: conn} do
    assert {:ok, user} = Auth.create_user(@sign_up_params, &"~~key#{&1}~~")

    receive do
      {:email, email} ->
        [_, key] = Regex.run(~r{~~key(.+)~~}, email.text_body)
        conn = get(conn, Routes.auth_path(conn, :activate, key))

        assert html_response(conn, 200) =~ ~r{Welcome to Keila!\s*</h1>}
        assert %{activated_at: %DateTime{}} = Repo.get(Auth.User, user.id)
    end
  end

  @tag :auth_controller
  test "activation is required", %{conn: conn} do
    assert {:ok, _user} = Auth.create_user(@sign_up_params)
    conn = post(recycle(conn), Routes.auth_path(conn, :login, user: @sign_up_params))
    conn = get(recycle(conn), "/")
    assert redirected_to(conn) == Routes.auth_path(conn, :activate_required)
  end

  @tag :auth_controller
  test "activation link can be resent", %{conn: conn} do
    assert {:ok, _user} = Auth.create_user(@sign_up_params)
    conn = post(conn, Routes.auth_path(conn, :login, user: @sign_up_params))
    conn = post(recycle(conn), Routes.auth_path(conn, :post_activate_resend), user: %{})

    assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
    assert_email_sent()
  end

  describe "reset password form" do
    @tag :auth_controller
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :reset))
      assert html_response(conn, 200) =~ ~r{Reset your password\.\s*</h1>}
    end

    @tag :auth_controller
    test "sends email for existing users", %{conn: conn} do
      user = insert!(:user)
      conn = post(conn, Routes.auth_path(conn, :reset), user: %{email: user.email})
      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_email_sent()
    end

    @tag :auth_controller
    test "shows no error for non-existent users", %{conn: conn} do
      conn =
        post(conn, Routes.auth_path(conn, :reset), user: %{email: "non-existent@example.com"})

      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_no_email_sent()
    end

    @tag :auth_controller
    test "shows error when not filled out", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :reset), user: %{})
      assert html_response(conn, 400) =~ ~r{Reset your password\.\s*</h1>}

      conn = post(conn, Routes.auth_path(conn, :reset), %{})
      assert html_response(conn, 400) =~ ~r{Reset your password\.\s*</h1>}

      assert_no_email_sent()
    end
  end

  describe "reset password change password form" do
    @tag :auth_controller
    test "shows form", %{conn: conn} do
      user = insert!(:user)
      {:ok, %{key: key}} = Auth.create_token(%{user_id: user.id, scope: "auth.reset"})
      conn = get(conn, Routes.auth_path(conn, :reset_change_password, key))
      assert html_response(conn, 200) =~ ~r{Reset your password\.\s*</h1>}
    end

    @tag :auth_controller
    test "validates token", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :reset_change_password, "invalid-token"))
      assert html_response(conn, 404) =~ ~r{That didn’t work :-\(\s*</h1>}
    end

    @tag :auth_controller
    test "validates errors", %{conn: conn} do
      user = insert!(:user)
      {:ok, %{key: key}} = Auth.create_token(%{user_id: user.id, scope: "auth.reset"})
      params = %{"password" => "too-short"}
      conn = post(conn, Routes.auth_path(conn, :reset_change_password, key), user: params)
      assert html_response(conn, 400) =~ ~r{Reset your password\.\s*</h1>}
    end

    @tag :auth_controller
    test "resets password", %{conn: conn} do
      user = insert!(:user)
      user_id = user.id
      {:ok, %{key: key}} = Auth.create_token(%{user_id: user.id, scope: "auth.reset"})
      params = %{"password" => "NewSecurePassword123"}
      conn = post(conn, Routes.auth_path(conn, :reset_change_password, key), user: params)
      assert html_response(conn, 200) =~ ~r{Your password was changed!\s*</h1>}

      assert {:ok, %{id: ^user_id}} =
               Auth.find_user_by_credentials(%{
                 "email" => user.email,
                 "password" => "NewSecurePassword123"
               })
    end

    @tag :auth_controller
    test "performs login after success", %{conn: _conn} do
      # TODO
    end
  end

  describe "login form" do
    @tag :auth_controller
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :login))
      assert html_response(conn, 200) =~ ~r{Sign in.\s*</h1>}
    end

    @tag :auth_controller
    test "accepts correct password", %{conn: conn} do
      {:ok, user} = Auth.create_user(@sign_up_params)
      Auth.activate_user(user.id)

      conn = post(conn, Routes.auth_path(conn, :login, user: @sign_up_params))
      conn = get(recycle(conn), "/")
      assert conn.assigns.current_user
    end

    @tag :auth_controller
    test "rejects incorrect or empty password", %{conn: conn} do
      {:ok, user} = Auth.create_user(@sign_up_params)
      Auth.activate_user(user.id)

      params = Map.put(@sign_up_params, "password", "wrong")
      conn = post(conn, Routes.auth_path(conn, :login, user: params))
      conn = get(recycle(conn), "/")
      refute conn.assigns.current_user

      params = Map.put(@sign_up_params, "password", nil)
      conn = post(conn, Routes.auth_path(conn, :login, user: params))
      conn = get(recycle(conn), "/")
      refute conn.assigns.current_user
    end
  end

  describe "logout route" do
    @tag :auth_controller
    test "signs user out", %{conn: conn} do
      {:ok, user} = Auth.create_user(@sign_up_params)
      Auth.activate_user(user.id)

      conn = post(conn, Routes.auth_path(conn, :login, user: @sign_up_params))
      conn = get(recycle(conn), "/")
      assert conn.assigns.current_user

      conn = get(recycle(conn), Routes.auth_path(conn, :logout))
      conn = get(recycle(conn), "/")
      refute conn.assigns.current_user
    end
  end
end
