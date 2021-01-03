defmodule KeilaWeb.AuthControllerTest do
  use KeilaWeb.ConnCase
  import Swoosh.TestAssertions
  import Keila.Factory
  alias Keila.{Repo, Auth}

  @sign_up_params %{"email" => "foo@bar.com", "password" => "BatteryHorseStaple"}

  describe "sign up form" do
    @tag :auth_controller
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :register))
      assert html_response(conn, 200) =~ "Register your Keila account now"
    end

    @tag :auth_controller
    test "allows registration with valid params", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :register), user: @sign_up_params)
      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_email_sent()
      assert %{activated_at: nil} = Repo.one(Auth.User)
    end

    @tag :auth_controller
    test "shows error with invalid params", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :register))
      assert html_response(conn, 400) =~ "Register your Keila account now"

      conn = post(conn, Routes.auth_path(conn, :register), user: %{})
      assert html_response(conn, 400) =~ "Register your Keila account now"

      conn =
        post(conn, Routes.auth_path(conn, :register), user: %{"email" => "", "password" => ""})

      assert html_response(conn, 400) =~ "Register your Keila account now"

      conn =
        post(conn, Routes.auth_path(conn, :register), user: Map.put(@sign_up_params, "email", ""))

      assert html_response(conn, 400) =~ "Register your Keila account now"

      conn =
        post(conn, Routes.auth_path(conn, :register),
          user: Map.put(@sign_up_params, "password", "")
        )

      assert html_response(conn, 400) =~ "Register your Keila account now"

      conn =
        post(conn, Routes.auth_path(conn, :register),
          user: Map.put(@sign_up_params, "password", "too-short")
        )

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
      assert {:ok, %{id: ^user_id}} = Auth.find_user_by_credentials(%{"email" => user.email, "password" => "NewSecurePassword123"})
    end

    @tag :auth_controller
    test "performs login after success", %{conn: conn} do
      # TODO
    end
  end
end
