defmodule KeilaWeb.UserAdminControllerTest do
  use KeilaWeb.ConnCase

  describe "GET /admin" do
    @tag :admin_controller
    test "is only accessible to users with admin permissions", %{conn: conn} do
      {root, user} = with_seed()

      conn = with_login(conn, user: user)
      conn = get(conn, Routes.user_admin_path(conn, :index))
      assert conn.status == 404

      conn = with_login(conn, user: root)
      conn = get(conn, Routes.user_admin_path(conn, :index))
      assert html_response(conn, 200) =~ ~r{Administer Users\s*</h1>}
    end

    @tag :admin_controller
    test "lists users", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: root)
      conn = get(conn, Routes.user_admin_path(conn, :index))

      assert html_response(conn, 200) =~ root.email
      assert html_response(conn, 200) =~ user.email
    end
  end

  describe "POST /admin/users" do
    @tag :admin_controller
    test "creates user as admin", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: root)

      params = %{"email" => user.email, "password" => user.password}
      conn = post(conn, Routes.user_admin_path(conn, :create, user: params))

      assert html_response(conn, 200) =~ user.email
    end

    @tag :admin_controller
    test "is only accessible to users with admin permissions", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: user)

      params = %{"email" => user.email, "password" => user.password}
      conn = post(conn, Routes.user_admin_path(conn, :create, user: params))

      assert conn.status == 404
    end
  end

  describe "DELETE /admin/users" do
    @tag :admin_controller
    test "shows deletion confirmation", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: root)

      params = %{"id" => user.id, "require_confirmation" => "true"}
      conn = delete(conn, Routes.user_admin_path(conn, :delete, user: params))

      assert html_response(conn, 200) =~ ~r{Delete Users\?\s*</h1>}
      assert html_response(conn, 200) =~ user.email
      refute html_response(conn, 200) =~ root.email
    end

    @tag :admin_controller
    test "deletes user", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: root)
      conn = delete(conn, Routes.user_admin_path(conn, :delete, user: %{"id" => user.id}))
      assert redirected_to(conn, 302) == Routes.user_admin_path(conn, :index)
      assert nil == Keila.Repo.get(Keila.Auth.User, user.id)
    end

    @tag :admin_controller
    test "impersonates user", %{conn: conn} do
      {root, user} = with_seed()
      conn = with_login(conn, user: root)

      conn = get(conn, Routes.user_admin_path(conn, :impersonate, user.id))
      assert redirected_to(conn, 302) == "/"

      conn = recycle(conn) |> get("/")
      assert conn.assigns.current_user.id == user.id
    end
  end
end
