defmodule Keila.Pagination do
  @moduledoc """
  Module for paginating Ecto Queries.
  """

  defstruct [:page, :data, :page_count]
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
    page_count = ceil(Keila.Repo.aggregate(query, :count, :id) / page_size)

    data =
      query
      |> limit(^page_size)
      |> offset(^(page * page_size))
      |> Keila.Repo.all()

    %__MODULE__{
      page: page,
      data: data,
      page_count: page_count
    }
  end
end
