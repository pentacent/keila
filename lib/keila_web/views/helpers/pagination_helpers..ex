defmodule KeilaWeb.PaginationHelpers do
  use Phoenix.HTML
  import KeilaWeb.IconHelper
  import Phoenix.LiveView.Helpers, only: [sigil_H: 2]

  @doc """
  Renders a pagination navigation element with the given `Keila.Pagination`
  struct and a route callback function or a phx-click event name.

  The callback function takes `n` (the page number) as an argument and returns
  the paginated route.
  """
  @spec pagination_nav(
          Keila.Pagination.t(),
          [href: (integer() -> String.t())] | [phx_click: String.t()]
        ) :: list()
  def pagination_nav(pagination, opts) do
    page = pagination.page
    page_count = pagination.page_count

    assigns = %{}

    ~H"""
    <%= if page > 0, do: pagination_button(page, page - 1, opts, render_icon(:chevron_left)) %>
    <%= pagination_button(page, 0, opts) %>
    <%= for n <- -3..3 do %>
      <%= if page + n > 0 and page + n < page_count - 1, do: pagination_button(page, page + n, opts) %>
    <% end %>
    <%= if page_count > 1, do: pagination_button(page, page_count - 1, opts) %>
    <%= if page < page_count - 1, do: pagination_button(page, page + 1, opts, render_icon(:chevron_right)) %>
    """
  end

  defp pagination_button(current_page, page, opts, content \\ nil)

  defp pagination_button(current_page, page, [href: route_fn], content) do
    route = route_fn.(page)
    class = if page == current_page, do: "button bg-green-500 text-black", else: "button"

    assigns = %{content: content || to_string(page + 1)}

    ~H"""
    <a href={ route } class={ class }><%= @content %></a>
    """
  end

  defp pagination_button(current_page, page, [phx_click: event_name], content) do
    class = if page == current_page, do: "button bg-green-600 text-white", else: "button"
    assigns = %{content: content || to_string(page + 1)}

    ~H"""
    <a phx-click={ event_name } phx-value-page={ page } class={ class }><%= @content %></a>
    """
  end
end
