defmodule Keila.Repo do
  use Ecto.Repo,
    otp_app: :keila,
    adapter: Ecto.Adapters.Postgres

  defmacro __using__(_opts) do
    quote do
      alias Ecto.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset
    end
  end
end
