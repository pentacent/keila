defmodule KeilaWeb.Api.Schema do
  @moduledoc """
  Helper module for creating OpenApiSpex schemas for JSON APIs.

  ## Usage
  ```
  use Keilaweb.Api.Schema
  build_open_api_schema(properties, opts)
  ```

  Properties is a nested map with Open API property specifications. Elixir types
  such as `:map` and `:utc_datetime` are automatically converted.

  ### Options:
  - `:meta` - Include the specified schema as meta specification in the schema.
  - `:with_pagination` - Include the default pagination schema as meta specification in the schema.
  - `:list` - Data schema is built as a list of objects with the given properties (e.g. for index responses).
  - `:only` - Only include given properties from provided property map.
  """

  defmacro __using__(_opts \\ []) do
    quote do
      require KeilaWeb.Api.Schema
      import KeilaWeb.Api.Schema
    end
  end

  defmacro build_open_api_schema(properties, opts \\ []) do
    quote bind_quoted: [properties: properties, opts: opts] do
      require OpenApiSpex

      title =
        __MODULE__ |> to_string() |> String.split(".") |> Enum.slice(-2..-1) |> Enum.join(".")

      properties
      |> schema_build(opts)
      |> Map.put(:title, title)
      |> OpenApiSpex.schema()
    end
  end

  defp schema_type(type) do
    case type do
      :map -> :object
      :utc_datetime -> :string
      other -> other
    end
  end

  defp schema_format(type) do
    case type do
      :utc_datetime -> :"date-time"
      _other -> nil
    end
  end

  @meta %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      page: %OpenApiSpex.Schema{
        type: :integer,
        description: "Current page of items (zero-indexed)",
        example: 0
      },
      page_size: %OpenApiSpex.Schema{
        type: :integer,
        description: "Number of items per page",
        example: 50
      },
      page_count: %OpenApiSpex.Schema{
        type: :integer,
        description: "Number of total pages",
        example: 5
      }
    }
  }

  def schema_build(properties, opts) when is_map(properties) do
    allowed_properties = Keyword.get(opts, :only, :all)
    properties = do_schema_build(properties, allowed_properties)

    list? = Keyword.get(opts, :list, false)
    meta = Keyword.get(opts, :meta, nil)
    with_pagination? = Keyword.get(opts, :with_pagination, false)
    required = Keyword.get(opts, :required, nil)

    data_schema =
      if list? do
        %OpenApiSpex.Schema{
          type: :array,
          items: %OpenApiSpex.Schema{
            type: :object,
            properties: properties,
            additionalProperties: false
          }
        }
      else
        %OpenApiSpex.Schema{
          type: :object,
          properties: properties,
          additionalProperties: false
        }
      end

    %{
      properties: %{
        data: data_schema
      },
      type: :object
    }
    |> maybe_add_meta(meta)
    |> maybe_put_pagination(with_pagination?)
    |> maybe_put_required(required)
  end

  defp do_schema_build(properties, allowed_properties \\ :all)

  defp do_schema_build(properties, allowed_properties) when is_map(properties) do
    for {key, property} <- properties,
        allowed_properties == :all || key in allowed_properties,
        into: %{} do
      properties = do_schema_build(Map.get(property, :properties))

      items =
        case do_schema_build(Map.get(property, :items)) do
          nil -> nil
          item_properties -> %OpenApiSpex.Schema{type: :object, properties: item_properties}
        end

      {key,
       %OpenApiSpex.Schema{
         type: schema_type(property.type),
         format: schema_format(property.type),
         description: Map.get(property, :description),
         enum: Map.get(property, :enum),
         example: Map.get(property, :example),
         properties: properties,
         items: items
       }}
    end
  end

  defp do_schema_build(nil, _), do: nil

  defp maybe_add_meta(schema, nil), do: schema

  defp maybe_add_meta(schema, meta) do
    put_in(schema, [:properties, :meta], meta)
  end

  defp maybe_put_pagination(schema, false), do: schema

  defp maybe_put_pagination(schema, true), do: maybe_add_meta(schema, @meta)

  defp maybe_put_required(schema, nil), do: schema

  defp maybe_put_required(schema, required_fields) do
    Enum.reduce(required_fields, schema, fn
      field, schema when is_atom(field) ->
        update_in(schema, [:properties, :data, Access.key!(:required)], fn
          nil -> [field]
          required -> [field | required]
        end)

      {path, required_fields}, schema when is_list(path) ->
        put_in(
          schema,
          [:properties, :data, Access.key!(:properties)] ++ path ++ [Access.key!(:required)],
          required_fields
        )
    end)
  end
end
