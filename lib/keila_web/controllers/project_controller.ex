defmodule KeilaWeb.ProjectController do
  use KeilaWeb, :controller
  alias Keila.{Projects, Contacts, Mailings, Templates}
  import Ecto.Changeset

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    projects = Projects.get_user_projects(conn.assigns.current_user.id)

    conn
    |> assign(:projects, projects)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    project = conn.assigns.current_project

    conn
    |> put_meta(:title, project.name)
    |> put_project_counts(project)
    |> render("show.html")
  end

  defp put_project_counts(conn, project) do
    conn
    |> assign(:senders_count, Mailings.get_project_senders(project.id) |> Enum.count())
    |> assign(:contacts_count, Contacts.get_project_contacts_count(project.id))
    |> assign(:forms_count, Contacts.get_project_forms(project.id) |> Enum.count())
    |> assign(:templates_count, Templates.get_project_templates(project.id) |> Enum.count())
    |> assign(:campaigns_count, Mailings.get_project_campaigns(project.id) |> Enum.count())
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    conn
    |> render_new(change(%Projects.Project{}))
  end

  @spec post_new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_new(conn, params) do
    user = conn.assigns.current_user

    case Projects.create_project(user.id, params["project"] || %{}) do
      {:ok, project} -> redirect(conn, to: Routes.project_path(conn, :show, project.id))
      {:error, changeset} -> render_new(conn, 400, changeset)
    end
  end

  defp render_new(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> assign(:changeset, changeset)
    |> put_meta(:title, gettext("New Project"))
    |> render("new.html")
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _) do
    project = conn.assigns.current_project
    render_edit(conn, change(project))
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, params) do
    project = conn.assigns.current_project

    case Projects.update_project(project.id, params["project"] || %{}) do
      {:ok, _project} -> redirect(conn, to: Routes.project_path(conn, :show, project.id))
      {:error, changeset} -> render_edit(conn, 400, changeset)
    end
  end

  defp render_edit(conn, status \\ 200, changeset) do
    project = conn.assigns.current_project

    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Edit %{project_name}", project_name: changeset.data.name))
    |> assign(:changeset, changeset)
    |> assign(:members, Projects.list_project_users(project.id))
    |> render("edit.html")
  end

  @spec post_add_member(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_add_member(conn, %{"user" => %{"email" => email}}) do
    project = conn.assigns.current_project

    case Keila.Auth.find_user_by_email(email) do
      nil ->
        conn
        |> put_flash(:error, gettext("No user with this email address exists."))
        |> redirect(to: Routes.project_path(conn, :edit, project.id))

      user ->
        case Projects.add_project_user(project, user) do
          :ok ->
            conn
            |> put_flash(:info, gettext("User was added to project."))
            |> redirect(to: Routes.project_path(conn, :edit, project.id))

          {:error, _changeset} ->
            conn
            |> put_flash(:error, gettext("Could not add user to project."))
            |> redirect(to: Routes.project_path(conn, :edit, project.id))
        end
    end
  end

  def post_add_member(conn, _) do
    conn |> put_status(404) |> halt()
  end

  @spec post_remove_member(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_remove_member(conn, %{"user_id" => user_id}) do
    project = conn.assigns.current_project

    if user_id != conn.assigns.current_user.id do
      case Keila.Auth.get_user(user_id) do
        nil ->
          conn |> put_status(404) |> halt()

        user ->
          :ok = Projects.remove_project_user(project, user)

          conn
          |> put_flash(:info, gettext("User was removed from project."))
          |> redirect(to: Routes.project_path(conn, :edit, project.id))
      end
    else
      conn |> put_status(404) |> halt()
    end
  end

  def post_remove_member(conn, _) do
    conn |> put_status(404) |> halt()
  end

  @spec delete(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete(conn, _) do
    project = conn.assigns.current_project
    changeset = change({project, %{delete_confirmation: :string}})
    render_delete(conn, changeset)
  end

  def post_delete(conn, params) do
    project = conn.assigns.current_project

    changeset =
      change({project, %{delete_confirmation: :string}})
      |> cast(params["project"] || %{}, [:delete_confirmation])
      |> validate_required([:delete_confirmation])
      |> validate_inclusion(:delete_confirmation, [project.name])

    if changeset.valid? do
      Projects.delete_project(project.id)
      redirect(conn, to: Routes.project_path(conn, :index))
    else
      {:error, changeset} = apply_action(changeset, :update)
      render_delete(conn, 400, changeset)
    end
  end

  defp render_delete(conn, status \\ 200, changeset) do
    project = conn.assigns.current_project

    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Delete %{project_name}", project_name: project.name))
    |> assign(:changeset, changeset)
    |> render("delete.html")
  end
end
