defmodule Keila.Pagination do
  @moduledoc """
  Module for paginating Ecto Queries.
  """

  defstruct [:page, :data, :count, :page_count]
  @type t :: %__MODULE__{}
  @type t(type) :: %__MODULE__{data: type}

  import Ecto.Query
  require Ecto.Query

  @doc """
  Paginates a query and retrieves data from Repo.

  ## Options:
  - `:page` - the page that should be retrieved. Defaults to `0`.
  - `:page_size` - the number of records per page. Defaults to `10`.
  """
  @spec paginate(Ecto.Query.t(), page: integer(), page_size: integer()) :: t()
  def paginate(query, opts \\ []) do
    page = Keyword.get(opts, :page, 0)
    page_size = Keyword.get(opts, :page_size, 10)
    id_field = get_id_field(query)
    count = Keila.Repo.aggregate(query, :count, id_field)
    page_count = ceil(count / page_size)

    data =
      query
      |> limit(^page_size)
      |> offset(^(page * page_size))
      |> Keila.Repo.all()

    %__MODULE__{
      page: page,
      data: data,
      count: count,
      page_count: page_count
    }
  end

  defp get_id_field(%{from: %Ecto.Query.FromExpr{source: {_, module}}}) do
    module.__schema__(:primary_key)
    |> List.first()
  end

  defp get_id_field(_query), do: :id
end
