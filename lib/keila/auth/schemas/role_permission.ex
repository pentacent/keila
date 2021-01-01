defmodule Keila.Auth.RolePermission do
  use Keila.Schema, prefix: "arp"

  schema "role_permissions" do
    belongs_to(:role, Keila.Auth.Role, type: Keila.Auth.Role.Id)
    belongs_to(:permission, Keila.Auth.Permission, type: Keila.Auth.Permission.Id)
    field(:is_inherited, :boolean)

    timestamps()
  end
end
