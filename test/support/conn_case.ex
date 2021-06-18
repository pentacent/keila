defmodule KeilaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use KeilaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.

  Provides the following convenience functions:

  - `with_seed/0`: Seeds database and returns tuple with two users: `{root, regular_user}`
  - `with_login/2`: Seeds database and returns conn with logged in session.
    Specifying `root: true` will log in root user instead of regular user.
    Specifying `user: Keila.User.t()` will log in given user and skip database seeding.
  - `with_login_and_project/2`: Behaves like `with_login/2` and creates project
    for logged in user. Returns `{conn, project}` tuple.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import KeilaWeb.ConnCase
      import Keila.Factory
      import Swoosh.TestAssertions

      alias KeilaWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint KeilaWeb.Endpoint

      @password "BatteryHorseStaple"

      defp with_seed() do
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

      defp with_login(conn, opts \\ []) do
        login_user =
          cond do
            not is_nil(Keyword.get(opts, :user)) -> Keyword.get(opts, :user)
            Keyword.get(opts, :root) == true -> with_seed() |> elem(1)
            true -> with_seed() |> elem(0)
          end

        conn =
          conn
          |> get(Routes.auth_path(conn, :logout))
          |> post(
            Routes.auth_path(conn, :login, user: %{email: login_user.email, password: @password})
          )

        path = redirected_to(conn, 302)

        conn
        |> recycle()
        |> get(path)
      end

      defp with_login_and_project(conn, opts \\ []) do
        conn = with_login(conn, opts)

        {:ok, project} =
          Keila.Projects.create_project(conn.assigns.current_user.id, %{name: "Foo Bar"})

        {conn, project}
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Keila.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Keila.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
