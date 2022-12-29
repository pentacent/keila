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

  @doc """
  Updates a single queryable and returns it.

  Returns `nil` if no update was   performed and raises
  `Ecto.MultipleResultsError`.if more than one row was updated.
  """
  @spec update_one(Ecto.Queryable.t(), updates :: Keyword.t(), opts :: Keyword.t()) ::
          term() | nil
  def update_one(queryable, updates, opts \\ []) do
    case __MODULE__.update_all(queryable, updates, opts) do
      {1, [one]} -> one
      {0, _} -> nil
      {n, _} -> raise Ecto.MultipleResultsError, queryable: queryable, count: n
    end
  end
end
