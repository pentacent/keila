defmodule KeilaWeb.AuthSession.Plug do
  alias Keila.Auth
  import Plug.Conn

  @spec init(any) :: list()
  def init(_), do: []

  @spec call(Plug.Conn.t(), any) :: Plug.Conn.t()
  def call(conn, _) do
    with session_token when is_binary(session_token) <- get_session(conn, :token),
         token = %Auth.Token{} <- Auth.find_token(session_token, "web.session"),
         user = %Auth.User{} <- Keila.Repo.get(Auth.User, token.user_id) do
      assign(conn, :current_user, user)
    else
      _ -> assign(conn, :current_user, nil)
    end
  end
end
