defmodule KeilaWeb.ContactView do
  use KeilaWeb, :view
  use Phoenix.HTML

  def table_sort_button(assigns) do
    assigns = assign(assigns, :active?, assigns[:current_key] == assigns[:key])

    ~H"""
    <button
      data-sort-key={@key}
      data-sort-order={if @active? and @current_order == 1, do: "-1", else: "1"}
      type="button"
      class={
        "w-6 px-1 rounded hover:bg-gray-600" <>
          ((@active? && " bg-gray-600 hover:bg-gray-700") || "")
      }
    >
      {if @active? and @current_order == -1,
        do: render_icon(:chevron_up),
        else: render_icon(:chevron_down)}
    </button>
    """
  end
end
