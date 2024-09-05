defmodule KeilaWeb.CreateUserLive do
  use KeilaWeb, :live_view
  alias Keila.Auth.User

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:changeset, Ecto.Changeset.change(%User{}))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.UserAdminView, "new.html", assigns)
  end

  @impl true
  def handle_event("validate", params, socket) do
    changeset =
      params["user"]
      |> User.creation_changeset()
      |> Map.replace!(:action, :insert)

    socket =
      socket
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end
end
