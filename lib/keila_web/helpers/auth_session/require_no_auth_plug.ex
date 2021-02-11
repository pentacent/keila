defmodule KeilaWeb.AuthSession.RequireNoAuthPlug do
  @moduledoc """
  Plug for ensuring there is currently no authenticated session.

  Redirects to "/" if there is an authenticated session.
  """
  alias Keila.Auth.User
  import Plug.Conn

  @spec init(any) :: list()
  def init(_), do: []

  @spec call(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def call(conn, _) do
    case conn.assigns.current_user do
      nil -> conn
      %User{activated_at: nil} -> assign(conn, :current_user, nil)
      _user -> redirect_halt(conn, "/")
    end
  end

  defp redirect_halt(conn, path) do
    conn
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
