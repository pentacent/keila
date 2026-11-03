defmodule KeilaWeb.AccountControllerTest do
  use KeilaWeb.ConnCase
  alias Keila.Auth

  describe "GET /account" do
    @tag :account_controller
    test "shows manage account page", %{conn: conn} do
      conn = with_login(conn)
      conn = get(conn, Routes.account_path(conn, :edit))
      assert html_response(conn, 200) =~ ~r{Change Password\s*</h2>}
    end
  end

  describe "PUT /account" do
    @tag :account_controller
    test "allows changing of password, ends existing sessions, and starts a new session", %{
      conn: conn
    } do
      conn = with_login(conn)
      previous_session_key = get_session(conn, :token)
      user_id = conn.assigns.current_user.id

      {:ok, %{key: other_session_key}} =
        Auth.create_token(%{user_id: user_id, scope: "web.session"})

      {:ok, %{key: api_key}} = Auth.create_api_key(user_id, "np_peter")

      password_params = %{"password" => "MyNewPassword"}

      conn = put(conn, Routes.account_path(conn, :post_edit), user: password_params)

      assert redirected_to(conn, 302) == Routes.account_path(conn, :edit)
      user = conn.assigns.current_user

      credentials = password_params |> Map.put("email", user.email)
      assert {:ok, %{id: ^user_id}} = Auth.find_user_by_credentials(credentials)

      assert nil == Auth.find_token(previous_session_key, "web.session")
      assert nil == Auth.find_token(other_session_key, "web.session")
      assert %Auth.Token{} = Auth.find_api_key(api_key)

      new_session_key = get_session(conn, :token)
      assert %Auth.Token{user_id: ^user_id} = Auth.find_token(new_session_key, "web.session")

      conn = conn |> recycle() |> get(Routes.account_path(conn, :edit))
      assert html_response(conn, 200) =~ ~r{New password saved.}
    end
  end
end
