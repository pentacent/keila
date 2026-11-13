defmodule KeilaWeb.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hooks for authentication and authorization.

  - `:require_auth` - like `KeilaWeb.AuthSession.Plug` and
    `KeilaWeb.AuthSession.RequireAuthPlug`: assigns `:current_user` from the
    session token. Redirects to the login page if there is no valid session and
    to the activation page if the user hasn't been activated yet.
  - `:require_project` - like `KeilaWeb.ProjectPlug`: assigns `:current_project`
    from `"project_id"` in the LiveView session. Raises `KeilaWeb.NotFoundError`
    if the user can't access the project.
  - `:require_admin` - like the admin check in `KeilaWeb.UserAdminController`:
    assigns `:is_admin?` and raises `KeilaWeb.NotFoundError` if the user isn't
    an administrator.

  `:require_project` and `:require_admin` must be used after `:require_auth`:

      on_mount {KeilaWeb.LiveAuth, :require_auth}
      on_mount {KeilaWeb.LiveAuth, :require_project}

  On the initial HTTP render, the assigns set on `conn` are reused via
  `assign_new/3`.
  """
  use KeilaWeb, :verified_routes
  import Phoenix.LiveView, only: [redirect: 2]
  import Phoenix.Component, only: [assign_new: 3]
  alias Keila.{Auth, Projects}

  def on_mount(:require_auth, _params, session, socket) do
    socket =
      assign_new(socket, :current_user, fn ->
        Auth.find_user_by_session_token(session["token"])
      end)

    case socket.assigns.current_user do
      nil -> {:halt, redirect(socket, to: ~p"/auth/login")}
      %Auth.User{activated_at: nil} -> {:halt, redirect(socket, to: ~p"/auth/activate")}
      %Auth.User{} -> {:cont, socket}
    end
  end

  def on_mount(:require_project, _params, session, socket) do
    user_id = socket.assigns.current_user.id

    socket =
      assign_new(socket, :current_project, fn ->
        Projects.get_user_project(user_id, session["project_id"])
      end)

    case socket.assigns.current_project do
      nil -> raise KeilaWeb.NotFoundError
      %Projects.Project{} -> {:cont, socket}
    end
  end

  def on_mount(:require_admin, _params, _session, socket) do
    user_id = socket.assigns.current_user.id

    socket =
      assign_new(socket, :is_admin?, fn ->
        Auth.has_permission?(user_id, Auth.root_group().id, "administer_keila")
      end)

    case socket.assigns.is_admin? do
      true -> {:cont, socket}
      false -> raise KeilaWeb.NotFoundError
    end
  end
end
