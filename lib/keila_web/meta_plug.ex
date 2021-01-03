defmodule KeilaWeb.MetaPlug do
  @moduledoc """
  Simple Plug for holding page meta information (title, description, etc).no_return()

  Usage in controllers:
      put_meta(:title, gettext("Title"))

  Usage in templates:
      get_meta(@conn, "Title", "Default")
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
