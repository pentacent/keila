defmodule KeilaWeb.AuthSession.Plug do
  alias Keila.Accounts
  alias Keila.Auth
  import Plug.Conn

  @spec init(any) :: list()
  def init(_), do: []

  @spec call(Plug.Conn.t(), any) :: Plug.Conn.t()
  def call(conn, _) do
    with session_token when is_binary(session_token) <- get_session(conn, :token),
         token = %Auth.Token{} <- Auth.find_token(session_token, "web.session"),
         user = %Auth.User{} <- Auth.get_user(token.user_id),
         account <- Accounts.get_user_account(user.id) do
      is_admin? = Auth.has_permission?(user.id, Auth.root_group().id, "administer_keila")

      conn
      |> assign(:current_user, user)
      |> assign(:current_account, account)
      |> assign(:is_admin?, is_admin?)
    else
      _ ->
        conn
        |> assign(:current_user, nil)
        |> assign(:current_account, nil)
        |> assign(:is_admin?, false)
    end
  end
end
