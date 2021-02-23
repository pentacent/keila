defmodule KeilaWeb.ContactView do
  use KeilaWeb, :view
  use Phoenix.HTML

  @spec pagination_nav(Plug.Conn.t(), Keila.Pagination.t()) :: list()
  def pagination_nav(conn, pagination) do
    page = pagination.page
    page_count = pagination.page_count

    [
      if(page > 0, do: pagination_button(conn, page - 1, caret_left()), else: []),
      pagination_button(conn, 0),
      for(
        n <- -3..3,
        do:
          if(page + n > 0 and page + n < page_count - 1,
            do: pagination_button(conn, page + n),
            else: []
          )
      ),
      if(page_count > 1, do: pagination_button(conn, page_count - 1), else: []),
      if(page < page_count - 1, do: pagination_button(conn, page + 1, caret_right()), else: [])
    ]
  end

  defp pagination_button(conn, n, content \\ nil) do
    route = Routes.contact_path(conn, :index, conn.assigns.current_project.id, %{"page" => n + 1})
    content_tag(:a, content || to_string(n + 1), href: route, class: "button")
  end

  defp caret_left,
    do: ~e{
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
    </svg>
  }

  defp caret_right, do: ~e{
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
    </svg>
  }
end
