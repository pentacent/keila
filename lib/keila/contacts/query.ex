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
  - `"$empty"` - checks if field is null, nil, or an empty string.
    `%{"first_name" => %{"$empty" => true}}` - matches if first_name is unset, nil, or ""
    `%{"data.tags" => %{"$empty" => empty}}` - matches if tags is unset, nil, "", an empty list or an empty object.
  - `"$in"` - queries if field value is part of a set.
     `%{"email" => %{"$in" => ["foo@example.com", "bar@example.com"]}}`
  - `"$like"` - queries if the field matches using the SQL `ILIKE` statement.
     `%{"email" => %{"$like" => "%keila.io"}}`

  ## Filtering on custom data (`data.*`)
  Any `data.`-prefixed path filters on the contact's JSONB `data` field, e.g.
  `%{"data.age" => %{"$gt" => 40}}`. All operators above are supported. Because
  custom data is untyped JSONB, comparison operators (`$gt`, `$gte`, `$lt`,
  `$lte`) require the stored value and the filter value to be the same JSON
  type, and only support numbers and strings:
  - If the field is missing, or its stored value is a different JSON type than
    the filter value (e.g. filtering `$gt: 40` against a stored string, or
    `$gt: "40"` against a stored number), the contact is filtered out rather
    than compared. This avoids JSONB's type-rank ordering (`Object > Array >
    Boolean > Number > String > Null`), which would otherwise silently produce
    a match/non-match based on type rather than value.
  - Numbers compare numerically when both sides are JSON numbers.
  - Strings (e.g. dates) compare lexicographically when both sides are JSON
    strings, which is only correct for zero-padded ISO 8601 date values.
  - Booleans, arrays, and objects never match `$gt`/`$gte`/`$lt`/`$lte`, since
    there's no sensible ordering to apply.
  `$like` operates on the text projection of the value and works for any scalar.

  # Filtering on received messages (messages)
  A `messages` map can be defined to filter contacts based on their received messages.
  All status fields (like `"opened_at"`) can be defined, as well as `"campaign_id"`.
  For convenience purposes, `"bounced_at"` can be defined to filter based on bounces
  regardless if they were hard or soft bounces.

  ## Sorting
  Using the `:sort` option, you can supply MongoDB-style sorting options:
  - `sort: %{"email" => 1}` will sort results by email in ascending order.
  - `sort: %{"email" => -1}` will sort results by email in descending order.

  Defaults to sorting by `inserted_at` and `email`.

  Sorting can be disabled by passing `sort: false`
  """

  use Keila.Repo
  alias Keila.Contacts.Contact

  @type opts :: {:filter, map()} | {:sort, map()}

  @fields ["id", "email", "inserted_at", "first_name", "last_name", "status", "double_opt_in_at"]
  @message_fields [
    "campaign_id",
    "sent_at",
    "opened_at",
    "clicked_at",
    "failed_at",
    "bounced_at",
    "soft_bounce_received_at",
    "hard_bounce_received_at",
    "complaint_received_at",
    "unsubscribed_at"
  ]

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
      from(c in Contact)
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
    from(q in query,
      as: :contact,
      distinct: true,
      where: ^build_and(input)
    )
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

  defp build_condition(field, %{"$empty" => empty?}) when is_atom(field) and is_boolean(empty?) do
    if Contact.__schema__(:type, field) == :string do
      dynamic([c], ^empty? == (is_nil(field(c, ^field)) or field(c, ^field) == ""))
    else
      dynamic([c], ^empty? == is_nil(field(c, ^field)))
    end
  end

  defp build_condition(field, %{"$in" => value}) when is_atom(field) and is_list(value),
    do: dynamic([c], field(c, ^field) in ^value)

  defp build_condition(field, %{"$like" => value}) when is_atom(field),
    do: dynamic([c], ilike(field(c, ^field), ^value))

  defp build_condition(field, value) when is_atom(field) and value in [nil],
    do: dynamic([c], is_nil(field(c, ^field)))

  defp build_condition(field, value)
       when is_atom(field) and (is_binary(value) or is_number(value)),
       do: dynamic([c], field(c, ^field) == ^value)

  defp build_condition("data." <> raw_path, input) do
    path = String.split(raw_path, ".")
    build_data_condition(path, input)
  end

  defp build_condition("messages", input) do
    dynamic(exists(from m in Keila.Mailings.Message, where: ^build_message_conditions(input)))
  end

  defp build_condition(field, value),
    do: raise(~s{Unsupported filter "#{field}": "#{inspect(value)}"})

  defp build_message_conditions(input) do
    base_condition = dynamic([m], m.contact_id == parent_as(:contact).id)

    @message_fields
    |> Enum.filter(&Map.has_key?(input, &1))
    |> Enum.reduce(base_condition, fn field_name, conditions ->
      field = String.to_existing_atom(field_name)
      value = Map.get(input, field_name)
      condition = build_message_condition(field, value)
      dynamic([], ^condition and ^conditions)
    end)
  end

  defp build_message_condition(:bounced_at, value) do
    hard_bounce_condition = build_message_condition(:hard_bounce_received_at, value)
    soft_bounce_condition = build_message_condition(:soft_bounce_received_at, value)

    dynamic([], ^hard_bounce_condition or ^soft_bounce_condition)
  end

  defp build_message_condition(field, %{"$gt" => value}),
    do: dynamic([r], field(r, ^field) > ^value)

  defp build_message_condition(field, %{"$gte" => value}),
    do: dynamic([r], field(r, ^field) >= ^value)

  defp build_message_condition(field, %{"$lt" => value}),
    do: dynamic([r], field(r, ^field) < ^value)

  defp build_message_condition(field, %{"$lte" => value}),
    do: dynamic([r], field(r, ^field) <= ^value)

  defp build_message_condition(field, %{"$empty" => empty?}),
    do: dynamic([r], ^empty? == is_nil(field(r, ^field)))

  defp build_message_condition(field, nil),
    do: dynamic([r], is_nil(field(r, ^field)))

  defp build_message_condition(field, value) when is_binary(value) or is_number(value),
    do: dynamic([r], field(r, ^field) == ^value)

  defp build_data_condition(path, input)

  defp build_data_condition(path, %{"$gt" => value}), do: build_data_comparison(path, value, :gt)

  defp build_data_condition(path, %{"$gte" => value}),
    do: build_data_comparison(path, value, :gte)

  defp build_data_condition(path, %{"$lt" => value}), do: build_data_comparison(path, value, :lt)

  defp build_data_condition(path, %{"$lte" => value}),
    do: build_data_comparison(path, value, :lte)

  defp build_data_condition(path, %{"$empty" => empty?}) when is_boolean(empty?) do
    is_null = dynamic([c], is_nil(fragment("?#>>?", c.data, ^path)))
    is_empty_string = dynamic([c], fragment("?#>>?", c.data, ^path) == "")
    is_empty_list = dynamic([c], fragment("?#>? = '[]'::jsonb", c.data, ^path))
    is_empty_object = dynamic([c], fragment("?#>? = '{}'::jsonb", c.data, ^path))

    dynamic(
      [c],
      ^empty? ==
        (^is_null or ^is_empty_string or ^is_empty_list or ^is_empty_object)
    )
  end

  defp build_data_condition(path, %{"$in" => value}) when is_list(value),
    do: dynamic([c], fragment("?#>?", c.data, ^path) in ^value)

  defp build_data_condition(path, %{"$like" => value}) do
    ilike = dynamic([c], ilike(fragment("?#>>?", c.data, ^path), ^value))

    dynamic([c], fragment("coalesce(?, FALSE)", ^ilike))
  end

  defp build_data_condition(path, value) when is_binary(value) or is_number(value) do
    value_in_array = [value]
    string_value = to_string(value)

    equals_string = dynamic([c], fragment("?#>>?", c.data, ^path) == ^string_value)
    array_contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value_in_array))
    dynamic([c], fragment("coalesce(?, FALSE)", ^equals_string or ^array_contains))
  end

  defp build_data_condition(path, value) when is_map(value) or is_list(value) do
    value_in_array = [value]

    contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value))
    array_contains = dynamic([c], fragment("?#>? @> ?", c.data, ^path, ^value_in_array))
    dynamic([c], ^contains or ^array_contains)
  end

  # Custom data is untyped JSONB, so `$gt`/`$gte`/`$lt`/`$lte` only make sense
  # between two values of the same JSON type. Comparing across types (e.g. a
  # number stored where a string is filtered for) would otherwise fall back to
  # JSONB's type-rank ordering (Object > Array > Boolean > Number > String >
  # Null), silently matching/excluding rows based on type rather than value.
  # The CASE guard (rather than a plain `and`) is required: Postgres does not
  # guarantee left-to-right/short-circuit evaluation of ANDed WHERE clauses, so
  # a bare type-check-and-cast could still attempt (and fail on) the numeric
  # cast for a row whose value isn't actually numeric.
  defp build_data_comparison(path, value, :gt) when is_number(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'number' THEN (?#>>?)::numeric > ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :gte) when is_number(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'number' THEN (?#>>?)::numeric >= ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :lt) when is_number(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'number' THEN (?#>>?)::numeric < ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :lte) when is_number(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'number' THEN (?#>>?)::numeric <= ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :gt) when is_binary(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'string' THEN (?#>>?) > ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :gte) when is_binary(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'string' THEN (?#>>?) >= ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :lt) when is_binary(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'string' THEN (?#>>?) < ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  defp build_data_comparison(path, value, :lte) when is_binary(value) do
    dynamic(
      [c],
      fragment(
        "CASE WHEN jsonb_typeof(?#>?) = 'string' THEN (?#>>?) <= ? ELSE false END",
        c.data,
        ^path,
        c.data,
        ^path,
        ^value
      )
    )
  end

  # Neither a number nor a string (e.g. a boolean, list, or map) - there's no
  # sensible ordering to apply, so the condition matches nothing.
  defp build_data_comparison(_path, _value, _op), do: false

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
