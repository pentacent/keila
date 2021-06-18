defmodule Keila.AdminTest do
  use Keila.DataCase, async: true
  alias Keila.{Repo, Projects, Projects.Project, Auth, Auth.User, Admin}

  @tag :admin
  test "purge user only deletes user and abandoned user project data" do
    _root = insert!(:group)

    {:ok, user1} = Auth.create_user(params(:user))
    {:ok, user2} = Auth.create_user(params(:user))
    {:ok, project1} = Projects.create_project(user1.id, params(:project))
    {:ok, project2} = Projects.create_project(user1.id, params(:project))

    # Projects can only be shared with Users in the same Account
    account = Keila.Accounts.get_user_account(user1.id)
    :ok = Keila.Accounts.set_user_account(user2.id, account.id)
    Auth.add_user_to_group(user2.id, project2.group_id)

    assert :ok = Admin.purge_user(user1.id)

    assert nil == Repo.get(User, user1.id)
    assert nil == Repo.get(Project, project1.id)
    assert [^project2] = Repo.all(Project)
  end
end
