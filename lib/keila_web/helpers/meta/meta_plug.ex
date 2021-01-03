defmodule KeilaWeb.Meta.Plug do
  @moduledoc """
  Simple Plug for holding page meta information (title,
  description, etc).

  Use with helper functions from `KeilaWeb.Meta`.
  """
  import Plug.Conn

  @spec init(term()) :: term()
  def init(_opts) do
    nil
  end

  @spec call(Plug.Conn.t(), term) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> put_private(:keila_meta, %{})
  end
end
