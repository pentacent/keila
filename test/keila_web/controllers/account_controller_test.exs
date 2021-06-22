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
    test "allows changing of password", %{conn: conn} do
      conn = with_login(conn)

      password_params = %{"password" => "MyNewPassword"}

      conn = put(conn, Routes.account_path(conn, :post_edit), user: password_params)

      assert html_response(conn, 200) =~ ~r{New password saved.}
      user = conn.assigns.current_user
      user_id = user.id

      credentials = password_params |> Map.put("email", user.email)
      assert {:ok, %{id: ^user_id}} = Auth.find_user_by_credentials(credentials)
    end
  end
end
