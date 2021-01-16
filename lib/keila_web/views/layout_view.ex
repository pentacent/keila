defmodule KeilaWeb.LayoutView do
  use KeilaWeb, :view
  use Phoenix.HTML

  def menu_link(conn, route, label, opts \\ []) do
    class =
      cond do
        conn.request_path == route ->
          "menu-link menu-link--active menu-link--active-exact"

        Keyword.get(opts, :exact, false) == false and
            String.starts_with?(conn.request_path, route) ->
          "menu-link menu-link--active"

        true ->
          "menu-link"
      end

    content_tag(:a, label, href: route, class: class)
  end
end
