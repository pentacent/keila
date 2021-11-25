defmodule Keila.Contacts.Query do
  @moduledoc """
  Module for querying Contacts.

  The `apply/2` function takes two arguments: a query (`Ecto.Query.t()`) and options
  for filtering and sorting the resulting data set.

  ## Filtering
  Using the `:filter` option, you can supply a MongoDB-style query map.

  ### Supported operators:
  - `"$not"` - logical not.
     `%{"$not" => {%"email" => "foo@bar.com"}}`
  - `"$or"` - logical or.
     `%{"$or" => [%{"email" => "foo@bar.com"}, %{"inserted_in" => "2020-01-01 00:00:00Z"}]}`
  - `"$gt"` - greater-than operator.
    `%{"inserted_at" => %{"$gt" => "2020-01-01 00:00:00Z"}}`
  - `"$gte"` - greater-than-equal operator.
  - `"$lt"` - lesser-than operator.
    `%{"inserted_at" => %{"$lt" => "2020-01-01 00:00:00Z"}}`
  - `"$lte"` - lesser-than-or-equal operator.
  - `"$in"` - queries if field value is part of a set.
     `%{"email" => %{"$in" => ["foo@example.com", "bar@example.com"]}}`
  - `"$like"` - queries if the field matches using the SQL `LIKE` statement.
     `%{"email" => %{"$like" => "%keila.io"}}`

  ## Sorting
  Using the `:sort` option, you can supply MongoDB-style sorting options:
  - `sort: %{"email" => 1}` will sort results by email in ascending order.
  - `sort: %{"email" => -1}` will sort results by email in descending order.

  Defaults to sorting by `inserted_at` and `email`.

  Sorting can be disabled by passing `sort: false`
  """

  use Keila.Repo

  @type opts :: {:filter, map()} | {:sort, map()}

  @fields ["id", "email", "inserted_at", "first_name", "last_name", "status"]

  @spec apply(Ecto.Query.t(), [opts]) :: Ecto.Query.t()
  def apply(query, opts) do
    query
    |> maybe_filter(opts)
    |> maybe_sort(opts)
  end

  @doc """
  Safely validates if the given query opts are valid.
  """
  @spec valid_opts?([opts]) :: boolean()
  def valid_opts?(opts) do
    try do
      from(c in Keila.Contacts.Contact)
      |> maybe_filter(opts)
      |> maybe_sort(opts)

      true
    rescue
      _ -> false
    end
  end

  defp maybe_filter(query, opts) do
    case Keyword.get(opts, :filter) do
      input when is_map(input) -> filter(query, input)
      _ -> query
    end
  end

  defp filter(query, input) do
    from(q in query, where: ^build_and(input))
  end

  defp build_and([]), do: true

  defp build_and(input) do
    Enum.reduce(input, [], fn
      {k, v}, [] ->
        build_condition(k, v)

      {k, v}, conditions ->
        dynamic([c], ^build_condition(k, v) and ^conditions)

      input, [] when is_map(input) or is_list(input) ->
        build_and(input)

      input, conditions when is_map(input) or is_list(input) ->
        dynamic([c], ^build_and(input) and ^conditions)
    end)
  end

  defp build_or(input) do
    Enum.reduce(input, [], fn
      input, [] -> build_and(input)
      input, conditions -> dynamic([c], ^build_and(input) or ^conditions)
    end)
  end

  defp build_condition("$and", input),
    do: build_and(input)

  defp build_condition("$or", input),
    do: build_or(input)

  defp build_condition("$not", input),
    do: dynamic(not (^build_and(input)))

  defp build_condition(field, input) when field in @fields,
    do: build_condition(String.to_existing_atom(field), input)

  defp build_condition(field, %{"$gt" => value}) when is_atom(field),
    do: dynamic([c], field(c, ^field) > ^value)

  defp build_condition(field, %{"$gte" => value}) when is_atom(field),
    do: dynamic([c], field(c, ^field) >= ^value)

  defp build_condition(field, %{"$lt" => value}) when is_atom(field),
    do: dynamic([c], field(c, ^field) < ^value)

  defp build_condition(field, %{"$lte" => value}) when is_atom(field),
    do: dynamic([c], field(c, ^field) <= ^value)

  defp build_condition(field, %{"$in" => value}) when is_atom(field) and is_list(value),
    do: dynamic([c], field(c, ^field) in ^value)

  defp build_condition(field, %{"$like" => value}) when is_atom(field),
    do: dynamic([c], like(field(c, ^field), ^value))

  defp build_condition(field, value) when is_atom(field) and value in [nil],
    do: dynamic([c], is_nil(field(c, ^field)))

  defp build_condition(field, value)
       when is_atom(field) and (is_binary(value) or is_number(value)),
       do: dynamic([c], field(c, ^field) == ^value)

  defp build_condition("data." <> raw_path, input) do
    path = String.split(raw_path, ".")
    build_data_condition(path, input)
  end

  defp build_condition(field, value),
    do: raise(~s{Unsupported filter "#{field}": "#{inspect(value)}"})

  defp build_data_condition(path, input)

  defp build_data_condition(path, %{"$gt" => value}),
    do: dynamic([c], fragment("?#>?", c.data, ^path) > ^value)

  defp build_data_condition(path, %{"$gte" => value}),
    do: dynamic([c], fragment("?#>?", c.data, ^path) >= ^value)

  defp build_data_condition(path, %{"$lt" => value}),
    do: dynamic([c], fragment("?#>?", c.data, ^path) < ^value)

  defp build_data_condition(path, %{"$lte" => value}),
    do: dynamic([c], fragment("?#>?", c.data, ^path) <= ^value)

  defp build_data_condition(path, %{"$in" => value}) when is_list(value),
    do: dynamic([c], fragment("?#>?", c.data, ^path) in ^value)

  defp build_data_condition(path, %{"$like" => value}),
    do: dynamic([c], like(fragment("?#>?", c.data, ^path), ^value))

  defp build_data_condition(path, value) when is_binary(value) or is_number(value) do
    value_in_array = [value]
    string_value = to_string(value)

    equals_string = dynamic([c], fragment("?#>>?", c.data, ^path) == ^string_value)
    array_contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value_in_array))
    dynamic([c], ^equals_string or ^array_contains)
  end

  defp build_data_condition(path, value) when is_map(value) or is_list(value) do
    value_in_array = [value]

    contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value))
    array_contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value_in_array))
    dynamic([c], ^contains or ^array_contains)
  end

  defp maybe_sort(query, opts) do
    case Keyword.get(opts, :sort) do
      false -> query
      opts when is_map(opts) -> sort(query, opts)
      _ -> sort(query, %{"inserted_at" => 1, "email" => 1})
    end
  end

  defp sort(query, input) do
    input
    |> Map.take(@fields)
    |> Enum.reverse()
    |> Enum.reduce(query, fn {field, direction}, query ->
      field = String.to_existing_atom(field)
      direction = if direction == -1, do: :desc, else: :asc

      order_by(query, [c], [{^direction, field(c, ^field)}])
    end)
  end
end
