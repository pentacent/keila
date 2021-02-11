defmodule KeilaWeb.AuthSession.RequireAuthPlug do
  @moduledoc """
  Plug for ensuring there is an active authenticated session.

  Redirects to login route if there is no authenticated session.
  Redirects to activate_required route if authenticated user has not
  been activated.

  ## Options
  - `allow_not_activated``- Allows non-activated users instead of redirecting
  them to the activated_required route. Defaults to `false`.
  """

  alias Keila.Auth.User
  alias KeilaWeb.Router.Helpers, as: Routes
  import Plug.Conn

  @spec init(list()) :: list()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def call(conn, opts) do
    case conn.assigns.current_user do
      nil ->
        redirect_halt(conn, :login)

      %User{activated_at: nil} ->
        if Keyword.get(opts, :allow_not_activated, false) do
          conn
        else
          redirect_halt(conn, :activate_required)
        end

      %User{} ->
        conn
    end
  end

  defp redirect_halt(conn, path) do
    conn
    |> Phoenix.Controller.redirect(to: Routes.auth_path(conn, path))
    |> halt()
  end
end
