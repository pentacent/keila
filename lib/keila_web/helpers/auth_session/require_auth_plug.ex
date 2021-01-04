defmodule KeilaWeb.AuthSession.RequireAuthPlug do
  @moduledoc """
  Plug for ensuring there is an active authenticated session.

  Redirects to login route if there is no authenticated session.
  Redirects to activate_required route if authenticated user has not
  been activated.
  """

  alias Keila.Auth
  alias KeilaWeb.Router.Helpers, as: Routes
  import Plug.Conn

  @spec init(any()) :: list()
  def init(_), do: []

  @spec call(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def call(conn, _) do
    case conn.assigns.current_user do
      nil ->
        redirect_halt(conn, Routes.auth_path(conn, :login))

      %Auth.User{activated_at: nil} ->
        redirect_halt(conn, Routes.auth_path(conn, :activate_required))

      %Auth.User{} ->
        conn
    end
  end

  defp redirect_halt(conn, path) do
    conn
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
