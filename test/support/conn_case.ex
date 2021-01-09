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

  Provides `with_login/1` function which creates a new activated
  user and starts a logged in session.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import KeilaWeb.ConnCase

      alias KeilaWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint KeilaWeb.Endpoint

      defp with_login(conn) do
        params = %{
          email: "test.user#{:crypto.strong_rand_bytes(12) |> Base.url_encode64()}@example.org",
          password: "BatteryHorseStaple"
        }

        {:ok, user} = Keila.Auth.create_user(params)
        Keila.Auth.activate_user(user.id)

        conn =
          conn
          |> get(Routes.auth_path(conn, :logout))
          |> post(Routes.auth_path(conn, :login, user: params))

        path = redirected_to(conn, 302)

        conn
        |> recycle()
        |> get(path)
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
