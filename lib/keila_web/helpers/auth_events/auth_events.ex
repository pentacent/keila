defmodule KeilaWeb.AuthEvents do
  @moduledoc """
  Helper module for logging auth events from a `Plug.Conn`.
  """
  import Plug.Conn
  alias Keila.Auth

  @max_user_agent_length 255

  @doc """
  Logs an auth event with the client IP and user agent from `conn`.

  See `Keila.Auth.log_event/4` for options.
  """
  @spec log_auth_event(Plug.Conn.t(), atom(), Keila.Auth.User.id() | nil, Keyword.t()) ::
          Plug.Conn.t()
  def log_auth_event(conn, type, user_id, opts \\ []) do
    data = opts |> Keyword.get(:data, %{}) |> maybe_put_user_agent(conn)
    Auth.log_event(type, user_id, conn.remote_ip, Keyword.put(opts, :data, data))

    conn
  end

  defp maybe_put_user_agent(data, conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] when user_agent != "" ->
        user_agent =
          user_agent
          |> String.replace_invalid()
          |> String.slice(0, @max_user_agent_length)

        Map.put(data, "user_agent", user_agent)

      _ ->
        data
    end
  end
end
