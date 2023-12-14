defmodule Keila.SeedHelper do
  import Keila.Factory
  @password "BatteryHorseStaple"
  def with_seed() do
    root_group = insert!(:group, name: "root", parent_id: nil)
    root_role = Keila.Repo.insert!(%Keila.Auth.Role{name: "root"})
    root_permission = Keila.Repo.insert!(%Keila.Auth.Permission{name: "administer_keila"})

    Keila.Repo.insert!(%Keila.Auth.RolePermission{
      role_id: root_role.id,
      permission_id: root_permission.id
    })

    root = insert!(:user, password_hash: Argon2.hash_pwd_salt(@password))
    Keila.Auth.add_user_group_role(root.id, root_group.id, root_role.id)
    {:ok, root} = Keila.Auth.activate_user(root.id)
    root_account = insert!(:account, group: build(:group, parent_id: root_group.id))
    :ok = Keila.Accounts.set_user_account(root.id, root_account.id)

    user = insert!(:user, password_hash: Argon2.hash_pwd_salt(@password))
    {:ok, user} = Keila.Auth.activate_user(user.id)
    account = insert!(:account, group: build(:group, parent_id: root_group.id))
    Keila.Accounts.set_user_account(user.id, account.id)

    {root, user}
  end
end
