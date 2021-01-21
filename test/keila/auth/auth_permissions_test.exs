defmodule Keila.AuthTest.Permissions do
  use Keila.DataCase, async: true
  alias Keila.Auth

  @tag :auth
  test "Retrieve root group" do
    group = insert!(:group, parent_id: nil)
    assert group == Auth.root_group()
  end

  @tag :auth
  test "There can only be one root group" do
    insert!(:group, parent_id: nil)

    assert_raise Ecto.ConstraintError, fn ->
      insert!(:group, parent_id: nil)
    end
  end

  @tag :auth
  test "Create a Group" do
    root = insert!(:group)
    assert {:ok, %Auth.Group{} = group} = Auth.create_group(params(:group, parent_id: root.id))
    assert {:ok, %Auth.Group{}} = Auth.create_group(params(:group, parent_id: group.id))
  end

  @tag :auth
  test "Creating a group requires a valid parent group" do
    assert {:error, %Ecto.Changeset{}} = Auth.create_group(params(:group, parent_id: nil))

    assert {:error, %Ecto.Changeset{}} =
             Auth.create_group(params(:group, parent_id: "ag_99999999"))
  end

  @tag :auth
  test "Update a Group" do
    group = insert!(:group)
    assert {:ok, %Auth.Group{}} = Auth.update_group(group.id, params(:group))
  end

  @tag :auth
  test "Create a Role" do
    assert {:ok, %Auth.Role{} = role} = Auth.create_role(params(:role))
    assert {:ok, %Auth.Role{}} = Auth.create_role(params(:role, parent_id: role.id))

    assert {:error, %Ecto.Changeset{}} =
             Auth.create_role(params(:group, parent_id: "ar_99999999"))
  end

  @tag :auth
  test "Update a Role" do
    role = insert!(:role)
    assert {:ok, %Auth.Role{}} = Auth.update_role(role.id, params(:role))
  end

  @tag :auth
  test "Create a Permission" do
    assert {:ok, %Auth.Permission{}} = Auth.create_permission(params(:group))
  end

  @tag :auth
  test "Update a Permission" do
    permission = insert!(:permission)
    assert {:ok, %Auth.Permission{}} = Auth.update_permission(permission.id, params(:permission))
  end

  @tag :auth
  test "Add User to Group" do
    user = insert!(:user)
    group = insert!(:group)
    group_id = group.id

    assert Auth.add_user_to_group(user.id, group.id) == :ok

    assert %{user_groups: [%{group_id: ^group_id}]} =
             Repo.get(Auth.User, user.id) |> Repo.preload(:user_groups)
  end

  @tag :auth
  test "Adding User to Group is idempotent" do
    user = insert!(:user)
    group = insert!(:group)
    group_id = group.id

    assert Auth.add_user_to_group(user.id, group.id) == :ok
    assert Auth.add_user_to_group(user.id, group.id) == :ok

    assert %{user_groups: [%{group_id: ^group_id}]} =
             Repo.get(Auth.User, user.id) |> Repo.preload(:user_groups)
  end

  @tag :auth
  test "Remove User from Group" do
    user = insert!(:user)
    group = insert!(:group)
    :ok = Auth.add_user_to_group(user.id, group.id)

    assert Auth.remove_user_from_group(user.id, group.id) == :ok
    assert %{user_groups: []} = Repo.get(Auth.User, user.id) |> Repo.preload(:user_groups)
  end

  @tag :auth
  test "Removing User from Group is idempotent" do
    user = insert!(:user)
    group = insert!(:group)
    :ok = Auth.add_user_to_group(user.id, group.id)

    assert Auth.remove_user_from_group(user.id, group.id) == :ok
    assert Auth.remove_user_from_group(user.id, group.id) == :ok
    assert %{user_groups: []} = Repo.get(Auth.User, user.id) |> Repo.preload(:user_groups)
  end

  @tag :auth
  test "User Groups can be listed" do
    user = insert!(:user)
    group_1 = insert!(:group)
    group_2 = insert!(:group, parent_id: group_1.id)

    :ok = Auth.add_user_to_group(user.id, group_1.id)
    :ok = Auth.add_user_to_group(user.id, group_2.id)

    assert groups = [%Auth.Group{}, %Auth.Group{}] = Auth.list_user_groups(user.id)
    assert group_1 in groups
    assert group_2 in groups
  end

  @tag :auth
  test "Check if User is in group" do
    root = insert!(:group)
    user = insert!(:user)
    group_1 = insert!(:group, parent_id: root.id)
    group_2 = insert!(:group, parent_id: root.id)

    :ok = Auth.add_user_to_group(user.id, group_1.id)

    assert true == Auth.user_in_group?(user.id, group_1.id)
    assert false == Auth.user_in_group?(user.id, group_2.id)
  end

  @tag :auth
  test "Grant user Group Role" do
    user = insert!(:user)
    group = insert!(:group)
    role = insert!(:role)
    role_id = role.id

    assert Auth.add_user_group_role(user.id, group.id, role.id) == :ok

    assert %{user_groups: [%{user_group_roles: [%{role_id: ^role_id}]}]} =
             Repo.get(Auth.User, user.id) |> Repo.preload(user_groups: :user_group_roles)
  end

  @tag :auth
  test "Granting User Group Roles is idempotent" do
    user = insert!(:user)
    group = insert!(:group)
    role = insert!(:role)
    role_id = role.id

    assert Auth.add_user_group_role(user.id, group.id, role.id) == :ok
    assert Auth.add_user_group_role(user.id, group.id, role.id) == :ok

    assert %{user_groups: [%{user_group_roles: [%{role_id: ^role_id}]}]} =
             Repo.get(Auth.User, user.id) |> Repo.preload(user_groups: :user_group_roles)
  end

  @tag :auth
  test "Remove User Group Role" do
    user = insert!(:user)
    group = insert!(:group)
    role = insert!(:role)
    :ok = Auth.add_user_group_role(user.id, group.id, role.id)

    assert Auth.remove_user_group_role(user.id, group.id, role.id) == :ok

    assert %{user_groups: [%{user_group_roles: []}]} =
             Repo.get(Auth.User, user.id) |> Repo.preload(user_groups: :user_group_roles)
  end

  @tag :auth
  test "Check direct permission" do
    user = insert!(:user, %{email: "foo@bar.com"})
    root = insert!(:group)
    groups = insert_n_groups_with_n_children(root, 10)

    role =
      insert!(:role, role_permissions: [build(:role_permission, permission: build(:permission))])

    group = Enum.random(groups)
    group_id = group.id
    permission = role.role_permissions |> Enum.random() |> Map.get(:permission)

    assert [] = Auth.groups_with_permission(user.id, permission.name)
    assert false == Auth.has_permission?(user.id, group.id, permission.name)

    :ok = Auth.add_user_group_role(user.id, group.id, role.id)

    assert true == Auth.has_permission?(user.id, group.id, permission.name)
    assert [%{id: ^group_id}] = Auth.groups_with_permission(user.id, permission.name)
  end

  @tag :auth
  test "Check inherited permission" do
    user = insert!(:user, %{email: "foo@bar.com"})
    root = insert!(:group)
    groups = insert_n_groups_with_n_children(root, 10)

    role =
      insert!(:role,
        role_permissions: [
          build(:role_permission, permission: build(:permission), is_inherited: true)
        ]
      )

    parent_group = Enum.random(groups)
    child_group = Enum.random(parent_group.children)
    permission = role.role_permissions |> Enum.random() |> Map.get(:permission)

    assert false == Auth.has_permission?(user.id, child_group.id, permission.name)

    :ok = Auth.add_user_group_role(user.id, parent_group.id, role.id)

    assert true == Auth.has_permission?(user.id, child_group.id, permission.name)

    groups_with_permission = Auth.groups_with_permission(user.id, permission.name)
    assert Enum.count(groups_with_permission) == 11

    for group <- groups_with_permission do
      assert group.id == parent_group.id || group.parent_id == parent_group.id
    end
  end

  defp insert_n_groups_with_n_children(root, n) do
    insert_n!(:group, n, fn _n ->
      [
        parent_id: root.id,
        children: build_n(:group, n, fn _n -> [parent_id: root.id] end)
      ]
    end)
  end
end
