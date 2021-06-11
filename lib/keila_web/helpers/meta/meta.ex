defmodule KeilaWeb.Meta do
  @moduledoc """
  Helper module for handling page meta information (title,
  description, etc).

  Must be used with `KeilaWeb.Meta.Plug`

  Usage in views:
      def meta(assigns, "page.html", :title, _default) do
        gettext("Title")
      end

  Usage in controllers (deprecated):
      put_meta(:title, gettext("Title"))

  Usage in templates:
      get_meta(@conn, @view_module, @view_template, "Title", "Default")
  """

  @spec put_meta(Plug.Conn.t(), atom(), term()) :: Plug.Conn.t()
  def put_meta(conn, key, value) do
    update_in(conn.private.keila_meta, &Map.put(&1, key, value))
  end

  @spec get_meta(Plug.Conn.t(), atom(), atom(), atom(), term()) :: term()
  # TODO Maybe rewrite as macro for better LiveView support?
  def get_meta(conn, view_module, view_template, key, default \\ nil) do
    if function_exported?(view_module, :meta, 3) do
      view_module.meta(view_template, key, conn.assigns) || default
    else
      Map.get(conn.private.keila_meta, key, default)
    end
  end
end
