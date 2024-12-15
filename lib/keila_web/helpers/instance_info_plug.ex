defmodule KeilaWeb.InstanceInfoPlug do
  @behaviour Plug
  import Plug.Conn

  @impl true
  def call(conn, _opts) do
    if conn.assigns[:is_admin?] do
      updates_available? = Keila.Instance.updates_available?()

      conn
      |> assign(:instance_updates_available?, updates_available?)
    else
      conn
    end
  end

  @impl true
  def init(opts), do: opts
end
