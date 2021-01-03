defmodule KeilaWeb.Meta do
  @moduledoc """
  Helper module for handling page meta information (title,
  description, etc).

  Must be used with `KeilaWeb.Meta.Plug`

  Usage in controllers:
      put_meta(:title, gettext("Title"))

  Usage in templates:
      get_meta(@conn, "Title", "Default")
  """

  @spec put_meta(Plug.Conn.t(), atom(), term()) :: Plug.Conn.t()
  def put_meta(conn, key, value) do
    update_in(conn.private.keila_meta, &Map.put(&1, key, value))
  end

  @spec get_meta(Plug.Conn.t(), atom(), term()) :: term()
  def get_meta(conn, key, default \\ nil) do
    # TODO Maybe rewrite as macro for better LiveView support?
    Map.get(conn.private.keila_meta, key, default)
  end
end
