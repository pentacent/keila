defmodule Keila.Repo do
  use Ecto.Repo,
    otp_app: :keila,
    adapter: Ecto.Adapters.Postgres

  defmacro __using__(_opts) do
    quote do
      alias Ecto.Changeset
      alias Keila.Repo
      require Ecto.Query
      import Ecto.Query
      import Ecto.Changeset

      defguard is_id(x) when is_binary(x) or is_integer(x)

      defp stringize_params(params) do
        case Enum.at(params, 0) do
          {k, _} when is_atom(k) ->
            params
            |> Enum.map(fn {k, v} -> {to_string(k), v} end)
            |> Enum.into(%{})

          _ ->
            params
        end
      end

      defp transaction_with_rescue(fun) do
        Repo.transaction(fn ->
          try do
            fun.()
          rescue
            e in Ecto.InvalidChangesetError -> Repo.rollback(e.changeset)
          end
        end)
      end
    end
  end
end
