defmodule KeilaWeb.AuthSession do
  @moduledoc """
  Helper module for authenticated sessions. Adds `@current_user`
  assign to routes.

  Use with `KeilaWeb.AuthSession.Plug` and
  `KeilaWeb.AuthSession.RequireAuthPlug`/`KeilaWeb.AuthSession.RequireNoAuthPlug`
  """
  import Plug.Conn
  alias Keila.Auth

  @doc """
  Start authenticated session.

  Creates `"web.session"` token for user with given `user_id` and puts
  it in the session.
  """
  @spec start_auth_session(Plug.Conn.t(), Keila.Auth.User.id()) :: Plug.Conn.t()
  def start_auth_session(conn, user_id) do
    {:ok, token} = Auth.create_token(%{scope: "web.session", user_id: user_id})

    conn
    |> clear_session()
    |> put_session(:token, token.key)
  end

  @doc """
  Clears the session and deletes session token if present.
  """
  @spec end_auth_session(Plug.Conn.t()) :: Plug.Conn.t()
  def end_auth_session(conn) do
    token = get_session(conn, :token)

    if is_binary(token) do
      Auth.find_and_delete_token(token, "web.session")
    end

    clear_session(conn)
  end
end
