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
    _root = insert!(:group)

    conn =
      conn
      |> with_login()
      |> post(Routes.project_path(conn, :post_new))

    assert html_response(conn, 400) =~ ~r{New Project\s*</h1>}
  end

  @tag :project_controller
  test "project form creates new project", %{conn: conn} do
    _root = insert!(:group)

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
    _root = insert!(:group)

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
    _root = insert!(:group)

    conn = with_login(conn)

    {:ok, project} = Keila.Projects.create_project(conn.assigns.current_user.id, params(:project))

    conn = get(conn, Routes.project_path(conn, :show, project.id))
    assert html_response(conn, 200) =~ ~r{#{project.name}\s*</h1>}

    conn =
      conn
      |> with_login()
      |> get(Routes.project_path(conn, :show, project.id))

    assert conn.status == 404
  end
end
