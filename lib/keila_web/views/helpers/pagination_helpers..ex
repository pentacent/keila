defmodule KeilaWeb.PaginationHelpers do
  use Phoenix.HTML
  use Phoenix.Component
  import KeilaWeb.IconHelper

  @doc """
  Renders a pagination navigation element with the given `Keila.Pagination`
  struct and a route callback function or a phx-click event name.

  The callback function takes `n` (the page number) as an argument and returns
  the paginated route.
  """
  attr :pagination, Keila.Pagination, required: true
  # TODO: Later versions of LiveView support {:fun, arity}
  attr :href, :any
  attr :phx_click, :string
  attr :phx_target, :string

  def pagination_nav(assigns) do
    assigns =
      assigns
      |> assign(:current_page, assigns.pagination.page)
      |> assign(:page_count, assigns.pagination.page_count)

    ~H"""
    <%= if @current_page > 0 do %>
      <.pagination_button page={@current_page - 1} {assigns}>
        <%= render_icon(:chevron_left) %>
      </.pagination_button>
    <% end %>

    <%= if @page_count > 0 do %>
      <.pagination_button page={0} {assigns} />
    <% end %>

    <%= for n <- -3..3, @current_page + n > 0 && @current_page + n + 1 < @page_count do %>
      <.pagination_button {assigns} page={@current_page + n} />
    <% end %>

    <%= if @page_count > 1 do %>
      <.pagination_button page={@page_count - 1} {assigns} />
    <% end %>

    <%= if @current_page < @page_count - 1 do %>
      <.pagination_button page={@current_page + 1} {assigns}>
        <%= render_icon(:chevron_right) %>
      </.pagination_button>
    <% end %>
    """
  end

  attr :page, :integer, required: true
  attr :current_page, :integer, required: true
  # TODO: Later versions of LiveView support {:fun, arity}
  attr :href, :any
  attr :phx_target, :any
  attr :phx_click, :any
  slot :inner_block

  defp pagination_button(assigns) do
    assigns =
      assigns
      |> assign(:href, if(assigns[:href], do: assigns.href.(assigns.page)))
      |> assign(
        :class,
        if(assigns.page == assigns.current_page,
          do: "button bg-emerald-500 text-black",
          else: "button"
        )
      )

    ~H"""
    <a
      class={@class}
      href={assigns[:href]}
      phx-click={assigns[:phx_click]}
      phx-target={assigns[:phx_target]}
      phx-value-page={@page}
    >
      <%= if @inner_block != [] do %>
        <%= render_slot(@inner_block) %>
      <% else %>
        <%= @page + 1 %>
      <% end %>
    </a>
    """
  end
end
