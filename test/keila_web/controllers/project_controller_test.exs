defmodule KeilaWeb.ProjectControllerTest do
  use KeilaWeb.ConnCase

  @tag :project_controller
  test "shows project form", %{conn: conn} do
    conn =
      conn
      |> with_login()
      |> get(Routes.project_path(conn, :new))

    assert html_response(conn, 200) =~ ~r{New Project\s*</h1>}
  end

  @tag :project_controller
  test "project form requires project name", %{conn: conn} do
    conn =
      conn
      |> with_login()
      |> post(Routes.project_path(conn, :post_new))

    assert html_response(conn, 400) =~ ~r{New Project\s*</h1>}
  end

  @tag :project_controller
  test "project form creates new project", %{conn: conn} do
    conn =
      conn
      |> with_login()
      |> post(Routes.project_path(conn, :post_new, project: %{name: "My Project"}))

    redirected_path = redirected_to(conn, 302)
    assert redirected_path =~ ~r{/projects/(.*)$}

    conn =
      conn
      |> recycle()
      |> get(redirected_path)

    assert html_response(conn, 200) =~ ~r{My Project\s*</h1>}
  end

  @tag :project_controller
  test "deleting a project requires confirmation", %{conn: conn} do
    conn = with_login(conn)

    {:ok, project} = Keila.Projects.create_project(conn.assigns.current_user.id, params(:project))

    conn = put(conn, Routes.project_path(conn, :post_delete, project.id, project: %{}))
    assert html_response(conn, 400)
    assert project == Keila.Projects.get_project(project.id)

    conn =
      put(
        conn,
        Routes.project_path(conn, :post_delete, project.id,
          project: %{delete_confirmation: project.name}
        )
      )

    assert redirected_to(conn, 302) =~ Routes.project_path(conn, :index)
    assert nil == Keila.Projects.get_project(project.id)
  end

  @tag :project_controller
  test "only authorized users can access a project", %{conn: conn} do
    conn = with_login(conn)

    {:ok, project} = Keila.Projects.create_project(conn.assigns.current_user.id, params(:project))

    conn = get(conn, Routes.project_path(conn, :show, project.id))
    assert html_response(conn, 200) =~ ~r{#{project.name}\s*</h1>}

    other_user = insert!(:activated_user)

    conn =
      conn
      |> with_login(user: other_user)
      |> get(Routes.project_path(conn, :show, project.id))

    assert conn.status == 404
  end

  @tag :project_controller
  test "project member can add and remove members", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    member = insert!(:user)

    conn =
      post(
        conn,
        Routes.project_path(conn, :post_add_member, project.id, user: %{email: member.email})
      )

    assert redirected_to(conn, 302) =~ Routes.project_path(conn, :edit, project.id)
    assert [_, _] = Keila.Projects.list_project_users(project.id)

    conn = delete(conn, Routes.project_path(conn, :post_remove_member, project.id, member.id))
    assert redirected_to(conn, 302) =~ Routes.project_path(conn, :edit, project.id)
    assert [_] = Keila.Projects.list_project_users(project.id)
  end

  @tag :project_controller
  test "all project members have the same rights to manage members", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    creator = conn.assigns.current_user
    other_user = insert!(:activated_user)
    :ok = Keila.Projects.add_project_user(project, other_user)

    conn =
      conn
      |> with_login(user: other_user)
      |> get(Routes.project_path(conn, :edit, project.id))

    assert html_response(conn, 200) =~ "Project members"

    conn =
      conn
      |> delete(Routes.project_path(conn, :post_remove_member, project.id, creator.id))

    assert redirected_to(conn, 302) =~ Routes.project_path(conn, :edit, project.id)
    assert [^other_user] = Keila.Projects.list_project_users(project.id)
  end

  @tag :project_controller
  test "cannot remove yourself from a project", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    user_id = conn.assigns.current_user.id

    conn = delete(conn, Routes.project_path(conn, :post_remove_member, project.id, user_id))
    assert conn.status == 404
    assert [_] = Keila.Projects.list_project_users(project.id)
  end

  @tag :project_controller
  test "user that is not a member cannot manage project members", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    other_user = insert!(:activated_user)

    conn =
      conn
      |> with_login(user: other_user)
      |> post(
        Routes.project_path(conn, :post_add_member, project.id,
          user: %{email: "someone@example.com"}
        )
      )

    assert conn.status == 404
  end

  @tag :project_controller
  test "cannot add a user that does not exist", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    conn =
      post(
        conn,
        Routes.project_path(conn, :post_add_member, project.id,
          user: %{email: "nonexistent@example.com"}
        )
      )

    assert redirected_to(conn, 302) =~ Routes.project_path(conn, :edit, project.id)
    assert [_] = Keila.Projects.list_project_users(project.id)
  end
end
