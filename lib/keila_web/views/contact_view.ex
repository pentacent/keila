defmodule KeilaWeb.ContactView do
  use KeilaWeb, :view
  use Phoenix.HTML

  def delete_form(conn, id) do
    route = Routes.contact_path(conn, :delete, conn.assigns.current_project.id)

    form_for(conn, route, [as: :contact, id: "delete-form-#{id}", method: "delete"], fn f ->
      [
        hidden_input(f, :require_confirmation, value: "true"),
        hidden_input(f, :id, value: id)
      ]
    end)
  end

  def delete_button(id) do
    content_tag(
      :button,
      ~e{
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          },
      class: "button button--text",
      form: "delete-form-#{id}"
    )
  end

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
