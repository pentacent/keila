defmodule KeilaWeb.PaginationHelpers do
  use Phoenix.HTML
  import KeilaWeb.IconHelper

  @doc """
  Renders a pagination navigation element with the given `Keila.Pagination`
  struct and route callback function.

  The callback function takes `n` (the page number) as an argument and returns
  the paginated route.
  """
  @spec pagination_nav(Keila.Pagination.t(), (integer() -> String.t())) :: list()
  def pagination_nav(pagination, route_fn) do
    page = pagination.page
    page_count = pagination.page_count

    [
      if(page > 0, do: pagination_button(page - 1, route_fn, render_icon(:chevron_left)), else: []),
      pagination_button(0, route_fn),
      for(
        n <- -3..3,
        do:
          if(page + n > 0 and page + n < page_count - 1,
            do: pagination_button(page + n, route_fn),
            else: []
          )
      ),
      if(page_count > 1, do: pagination_button(page_count - 1, route_fn), else: []),
      if(page < page_count - 1,
        do: pagination_button(page + 1, route_fn, render_icon(:chevron_right)),
        else: []
      )
    ]
  end

  defp pagination_button(n, route_fn, content \\ nil) do
    route = route_fn.(n)
    content_tag(:a, content || to_string(n + 1), href: route, class: "button")
  end
end
