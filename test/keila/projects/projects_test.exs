defmodule Keila.ProjectsTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Auth}
  alias Projects.Project

  @tag :projects
  test "Creating a project also creates an Auth.Group and adds user to it" do
    _root = insert!(:group)
    user = insert!(:user)
    params = %{"name" => "My Project"}
    assert {:ok, project = %Project{}} = Projects.create_project(user.id, params)
    assert [group] = Auth.list_user_groups(user.id)
    assert project.group_id == group.id
  end

  @tag :projects
  test "When creating a project fails, Auth.Group creation is rolled back" do
    _root = insert!(:group)
    user = insert!(:user)
    assert {:error, %Ecto.Changeset{data: %Project{}}} = Projects.create_project(user.id, %{})
    assert [] = Auth.list_user_groups(user.id)
  end

  @tag :projects
  test "Update project name" do
    group = insert!(:group)
    project = insert!(:project, group: group)
    name = "New Project Name"
    assert {:ok, %Project{name: ^name}} = Projects.update_project(project.id, %{name: name})
  end

  @tag :projects
  test "Delete project is idempotent" do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, %{"name" => "My Project"})
    assert :ok = Projects.delete_project(project.id)
    assert [] = Auth.list_user_groups(user.id)
  end

  @tag :projects
  test "Only auhtorized user can retrieve project with get_user_project/2" do
    _root = insert!(:group)
    user1 = insert!(:user)
    user2 = insert!(:user)
    {:ok, project} = Projects.create_project(user1.id, %{"name" => "My Project"})
    assert project == Projects.get_user_project(user1.id, project.id)
    assert nil == Projects.get_user_project(user2.id, project.id)
  end
end
