defmodule KeilaWeb.InstanceAdminController do
  use KeilaWeb, :controller

  alias Keila.Instance

  plug :authorize

  def show(conn, _) do
    update_checks_enabled? = Instance.update_checks_enabled?()
    available_updates = Instance.get_available_updates()
    current_version = Instance.current_version()

    host =
      Routes.project_url(conn, :index)
      |> String.replace(~r"https?://", "")
      |> String.replace("/", "")

    conn
    |> assign(:update_checks_enabled?, update_checks_enabled?)
    |> assign(:available_updates, available_updates)
    |> assign(:current_version, current_version)
    |> assign(:host, host)
    |> render("show.html")
  end

  defp authorize(conn, _) do
    case conn.assigns.is_admin? do
      true -> conn
      false -> conn |> put_status(404) |> halt()
    end
  end
end
