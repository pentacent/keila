defmodule KeilaWeb.LayoutView do
  use KeilaWeb, :view
  use Phoenix.HTML
  import KeilaWeb.IconHelper

  def menu_link(conn, controller, action, route_params, label, opts \\ []) do
    path = get_path(conn, controller, action, route_params)
    menu_link(conn, path, label, opts)
  end

  defp menu_link(conn, path, label, opts) when is_binary(path) do
    class =
      [
        "menu-link",
        if(active_path?(conn, path, opts), do: "menu-link--active"),
        if(conn.request_path == path, do: "menu-link--active-exact"),
        if(Keyword.get(opts, :indent) == 1, do: "ml-4")
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    icon = Keyword.get(opts, :icon, nil)

    assigns = %{label: label, icon: icon}

    ~H"""
      <a href={ path } class={ class }>
        <%= if icon do %>
          <span class="flex h-4 w-4">
            <%= render_icon(icon) %>
          </span>
        <% end %>
        <%= label %>
      </a>
    """
  end

  defp get_path(conn, controller, action, route_params) do
    params = [conn | [action | route_params]]
    apply(Routes, :"#{controller}_path", params)
  end

  @spec active_path?(String.t(), String.t(), Keyword.path()) :: boolean()
  def active_path?(conn = %{request_path: current_path}, path, ops) do
    exact? = Keyword.get(ops, :exact, false)

    if exact? do
      path == current_path
    else
      exclude =
        Keyword.get(ops, :exclude, [])
        |> Enum.map(fn {controller, action, route_params} ->
          get_path(conn, controller, action, route_params)
        end)

      String.starts_with?(current_path, path) && current_path not in exclude
    end
  end

  defp show_project_submenu?(conn, current_project) do
    conn.request_path in [
      Routes.project_path(conn, :show, current_project.id),
      Routes.project_path(conn, :edit, current_project.id)
    ] ||
      String.starts_with?(conn.request_path, Routes.sender_path(conn, :index, current_project.id))
  end
end
