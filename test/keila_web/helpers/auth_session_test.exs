defmodule KeilaWeb.AuthSessionTest do
  use KeilaWeb.ConnCase
  import Keila.Factory
  alias KeilaWeb.AuthSession

  @session_opts Plug.Session.init(
                  store: :cookie,
                  key: "_keila_key",
                  signing_salt: "foo-salt"
                )

  setup do
    {root, user} = with_seed()
    %{root: root, user: user}
  end

  defp init_session(conn) do
    conn
    |> Map.put(:secret_key_base, :crypto.strong_rand_bytes(64))
    |> Plug.Session.call(@session_opts)
    |> fetch_session()
  end

  defp init_user_session(conn, user) do
    conn
    |> init_session()
    |> AuthSession.start_auth_session(user.id)
    |> AuthSession.Plug.call([])
  end

  defp init_no_user_session(conn) do
    conn
    |> init_session()
    |> AuthSession.Plug.call([])
  end

  describe "AuthSession.Plug" do
    @tag :auth_session
    test "puts nil @current_user assign", %{conn: conn} do
      conn =
        conn
        |> init_session()
        |> AuthSession.Plug.call([])

      assert conn.assigns.current_user == nil
    end

    @tag :auth_session
    test "puts @current_user assign", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> AuthSession.start_auth_session(user.id)
        |> AuthSession.Plug.call([])

      assert conn.assigns.current_user == user
    end

    @tag :auth_session
    test "puts @is_admin? assign", %{conn: conn, user: user, root: root} do
      conn =
        conn
        |> init_session()
        |> AuthSession.start_auth_session(user.id)
        |> AuthSession.Plug.call([])

      assert conn.assigns.is_admin? == false

      conn =
        conn
        |> init_session()
        |> AuthSession.start_auth_session(root.id)
        |> AuthSession.Plug.call([])

      assert conn.assigns.is_admin? == true
    end
  end

  describe "AuthSession.RequireNoAuthPlug" do
    @tag :auth_session
    test "redirects to / if logged in", %{conn: conn} do
      user = insert!(:user, activated_at: DateTime.utc_now() |> DateTime.truncate(:second))
      conn = init_user_session(conn, user) |> AuthSession.RequireNoAuthPlug.call([])

      assert redirected_to(conn, 302) == "/"
    end

    @tag :auth_session
    test "doesn't redirect if not logged in", %{conn: conn} do
      conn = init_no_user_session(conn)
      assert conn == AuthSession.RequireNoAuthPlug.call(conn, [])
    end

    @tag :auth_session
    test "treats non-activated users as not logged in and nils @current_user", %{conn: conn} do
      user = insert!(:user, activated_at: nil)
      conn = init_user_session(conn, user) |> AuthSession.RequireNoAuthPlug.call([])

      refute conn.halted
      assert conn.assigns.current_user == nil
    end
  end

  describe "AuthSession.RequireAuthPlug" do
    @tag :auth_session
    test "redirects to login without auth session", %{conn: conn} do
      conn = init_no_user_session(conn) |> AuthSession.RequireAuthPlug.call([])
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login)
    end

    @tag :auth_session
    test "requires activated user", %{conn: conn} do
      user = insert!(:user, activated_at: nil)
      conn = init_user_session(conn, user) |> AuthSession.RequireAuthPlug.call([])

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate_required)
    end

    @tag :auth_session
    test "doesn’t redirect if activated user is logged in", %{conn: conn} do
      user = insert!(:user, activated_at: DateTime.utc_now() |> DateTime.truncate(:second))
      conn = init_user_session(conn, user)

      assert conn == AuthSession.RequireAuthPlug.call(conn, [])
    end
  end
end
