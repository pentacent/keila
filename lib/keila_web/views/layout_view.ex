defmodule KeilaWeb.LayoutView do
  use KeilaWeb, :view
  use Phoenix.HTML

  def menu_link(conn_or_socket, route, label) do
    class =
      if conn_or_socket.request_path == route do
        "menu-link menu-link--active"
      else
        "menu-link"
      end

    content_tag(:a, label, href: route, class: class)
  end
end
