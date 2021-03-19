defmodule Keila.Templates.StyleTemplate do
  @moduledoc """
  Module with functions for user-facing style templating.

  Style templates are lists of tuples, each representing a group of styles that
  are grouped together semantically.
  For an example, refer to `@style_template` in `Keila.Templates.DefaultTemplate`.
  """
  @type t :: list()

  @doc """
  Applies parsed CSS styles to a style template.
  """
  @spec apply_values_from_css(t(), Keila.Templates.Css.t()) :: t()
  def apply_values_from_css(template, styles) do
    Enum.map(template, fn {group_label, rows} ->
      rows =
        Enum.map(rows, fn row ->
          selector = row[:selector]
          property = row[:property]

          with {_, property_list} <- Enum.find(styles, &match?({^selector, _}, &1)),
               {_, value} <- Enum.find(property_list, &match?({^property, _}, &1)) do
            Map.put(row, :value, value)
          else
            _ -> row
          end
        end)

      {group_label, Enum.reverse(rows)}
    end)
  end

  @doc """
  Applies HTML form params to a style template.
  """
  @spec apply_values_from_params(t(), map()) :: t()
  def apply_values_from_params(template, params) do
    Enum.map(template, fn {group_label, rows} ->
      rows =
        Enum.map(rows, fn row ->
          name = "#{row[:selector]}__#{row[:property]}"

          case Map.get(params, name) do
            nil -> row
            value -> Map.put(row, :value, value)
          end
        end)

      {group_label, Enum.reverse(rows)}
    end)
  end

  @doc """
  Builds a CSS representation of a style template.
  """
  @spec to_css(list()) :: Keila.Templates.Css.t()
  def to_css(template) do
    flattened_template =
      Enum.reduce(template, [], fn {_group_label, rows}, acc ->
        rows ++ acc
      end)

    flattened_template
    |> Enum.reduce([], fn row = %{selector: selector, property: property}, acc ->
      value = row[:value] || row[:default]

      index =
        Enum.find_index(acc, fn
          {^selector, _} -> true
          _other -> false
        end)

      if not is_nil(index) do
        List.update_at(acc, index, fn {selector, property_values} ->
          {selector, [{property, value} | property_values]}
        end)
      else
        [{selector, [{property, value}]} | acc]
      end
    end)
  end
end
