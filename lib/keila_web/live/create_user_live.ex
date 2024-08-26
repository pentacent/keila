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
      %User{}
      |> User.creation_changeset(params["user"])
      |> then(fn changeset ->
        if changeset.valid?,
          do: changeset,
          else: Ecto.Changeset.apply_action(changeset, :update) |> elem(1)
      end)

    socket =
      socket
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end
end
