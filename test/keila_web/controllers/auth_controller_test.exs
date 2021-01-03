defmodule KeilaWeb.AuthControllerTest do
  use KeilaWeb.ConnCase
  import Swoosh.TestAssertions
  import Keila.Factory
  alias Keila.{Repo, Auth}

  @sign_up_params %{"email" => "foo@bar.com", "password" => "BatteryHorseStaple"}

  describe "sign up form" do
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :register))
      assert html_response(conn, 200) =~ "Register your Keila account now"
    end

    @tag :wip
    test "allows registration with valid params", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :register), user: @sign_up_params)
      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_email_sent()
      assert %{activated_at: nil} = Repo.one(Auth.User)
    end

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

  @tag :wip
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
    test "shows form", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :reset))
      assert html_response(conn, 200) =~ ~r{Reset your password\.\s*</h1>}
    end

    test "sends email for existing users", %{conn: conn} do
      user = insert!(:user)
      conn = post(conn, Routes.auth_path(conn, :reset), user: %{email: user.email})
      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_email_sent()
    end

    test "shows no error for non-existent users", %{conn: conn} do
      conn =
        post(conn, Routes.auth_path(conn, :reset), user: %{email: "non-existent@example.com"})

      assert html_response(conn, 200) =~ ~r{Check your inbox!\s*</h1>}
      assert_no_email_sent()
    end

    test "shows error when not filled out", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :reset), user: %{})
      assert html_response(conn, 400) =~ ~r{Reset your password\.\s*</h1>}

      conn = post(conn, Routes.auth_path(conn, :reset), %{})
      assert html_response(conn, 400) =~ ~r{Reset your password\.\s*</h1>}

      assert_no_email_sent()
    end
  end

  # describe "sign up form" do

  # end
end
