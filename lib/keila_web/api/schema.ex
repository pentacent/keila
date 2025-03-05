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
    required_properties = required_properties(properties, allowed_properties)
    list? = Keyword.get(opts, :list, false)
    meta = Keyword.get(opts, :meta, nil)
    with_pagination? = Keyword.get(opts, :with_pagination, false)

    data_schema =
      if list? do
        %OpenApiSpex.Schema{
          type: :array,
          items: %OpenApiSpex.Schema{
            type: :object,
            properties: do_schema_build(properties, allowed_properties),
            required: required_properties,
            additionalProperties: false
          }
        }
      else
        %OpenApiSpex.Schema{
          type: :object,
          properties: do_schema_build(properties, allowed_properties),
          required: required_properties,
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
  end

  defp do_schema_build(properties, allowed_properties \\ :all)

  defp do_schema_build(properties, allowed_properties) when is_map(properties) do
    for {key, property} <- properties,
        allowed_properties == :all || key in allowed_properties,
        into: %{} do
      properties = do_schema_build(Map.get(property, :properties))
      required_properties = required_properties(Map.get(property, :properties))

      {key,
       %OpenApiSpex.Schema{
         type: schema_type(property.type),
         format: schema_format(property.type),
         description: Map.get(property, :description),
         example: Map.get(property, :example),
         properties: properties,
         required: required_properties
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

  defp required_properties(properties, allowed_properties \\ :all)

  defp required_properties(nil, _), do: nil
  defp required_properties([], _), do: nil

  defp required_properties(properties, allowed_properties) do
    properties
    |> Enum.filter(fn
      {key, %{required: true}} ->
        allowed_properties == :all || key in allowed_properties

      _ ->
        false
    end)
    |> Enum.map(fn {key, _} -> key end)
    |> then(fn
      [] -> nil
      required_properties -> required_properties
    end)
  end
end
