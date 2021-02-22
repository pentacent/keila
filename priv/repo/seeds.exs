# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

require Logger
alias Keila.{Repo, Auth}

if Keila.Repo.all(Auth.Group) == [] do
  group = Keila.Repo.insert!(%Auth.Group{name: "root"})
  role = Keila.Repo.insert!(%Auth.Role{name: "root"})
  permission = Keila.Repo.insert!(%Auth.Permission{name: "administer_keila"})
  Keila.Repo.insert!(%Auth.RolePermission{role_id: role.id, permission_id: permission.id})

  email = System.get_env("KEILA_USER")
  password = System.get_env("KEILA_PASSWORD")

  if email not in ["", nil] and password not in ["", nil] do
    case Keila.Auth.create_user(%{email: email, password: password}) do
      {:ok, user} ->
        Keila.Auth.activate_user(user.id)
        Keila.Auth.add_user_group_role(user.id, group.id, role.id)
        Logger.info("Created root user with #{email}")

      {:error, changeset} ->
        Keila.ReleaseTasks.rollback(0)

        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        Logger.error("Failed to create root user: #{inspect(errors)}")
        Logger.flush()
        System.halt(1)
    end
  end
else
  Logger.info("Database already populated, not populating database.")
end
