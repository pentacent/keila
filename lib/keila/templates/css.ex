defmodule Keila.Templates.Css do
  @moduledoc """
  Module for handling CSS styles with simple CSS parser.

  The parser is based on the [MDN CSS specifications](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference)
  """

  @type t :: list({String.t(), list({String.t(), String.t()})})

  @doc """
  Parses a CSS string.

  ## Usage

      iex> css = "div, p {border: 1px solid} a.class {font-family: serif, sans-serif; color: blue}"
      iex> Keila.Templates.Css.parse!(css)
      [{"div, p", [{"border", "1px solid"}]}, {"a.class", [{"font-family", "serif, sans-serif"}, {"color", "blue"}]}]
  """
  @spec parse!(String.t()) :: t()
  def parse!(empty) when empty in [nil, ""] do
    []
  end

  def parse!(input) do
    {:ok, rules, _, _, _, _} = __MODULE__.Parser.parse(input)

    rules
    |> Enum.reduce([], fn
      {:selector_list, selectors}, acc ->
        selector =
          selectors
          |> Enum.map(fn {:selector, selector} -> to_string(selector) end)
          |> Enum.join(", ")

        [{selector, []} | acc]

      {:property_list, property_list}, [{selector, []} | acc] ->
        property_list =
          property_list
          |> Enum.chunk_every(2)
          |> Enum.map(fn [property: property, value: value] ->
            {to_string(property), to_string(value)}
          end)

        [{selector, property_list} | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Encodes parsed styles as a CSS string.

  ## Options
  `:compact` - `boolean`, defaults to `true`. Encodes with a reduced amount of
  whitespace.

  ## Usage

      iex> styles = [{"div", [{"border", "1px solid"}]}, {"a.class", [{"text-decoration", "underline"}, {"color", "blue"}]}]
      iex> Keila.Templates.Css.encode(styles)
      "div{border:1px solid} a.class{text-decoration:underline;color:blue}"
  """
  @spec encode(t(), Keyword.t()) :: String.t()
  def encode(styles, opts \\ []) do
    compact? = Keyword.get(opts, :compact, true)

    before_value = if compact?, do: "", else: " "
    properties_separator = if compact?, do: "", else: " "
    rule_separator = if compact?, do: " ", else: "\n"

    styles
    |> Enum.map(fn {selector, property_values} ->
      property_values =
        property_values
        |> Enum.map(fn {property, value} -> "#{property}:#{before_value}#{value}" end)
        |> Enum.join(";#{properties_separator}")

      "#{selector}{#{property_values}}"
    end)
    |> Enum.join(rule_separator)
  end

  @doc """
  Merges two parsed stylesheets. Values from the second stylesheet take
  precedence over the first one.

  ## Usage

    iex> styles1 = Keila.Templates.Css.parse!("div {border: 1px solid} a.class {text-decoration: underline}")
    iex> styles2 = Keila.Templates.Css.parse!("div {border: none} a.class {color: blue}")
    iex> Keila.Templates.Css.merge(styles1, styles2)
    [{"div", [{"border", "none"}]}, {"a.class", [{"text-decoration", "underline"}, {"color", "blue"}]}]
  """
  @spec merge(t(), t()) :: t()
  def merge(styles1, styles2) do
    (styles1 ++ styles2)
    |> Enum.reduce([], fn {selector, _}, acc ->
      if selector in acc do
        acc
      else
        [selector | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.reduce([], fn selector, acc ->
      {_, property_list1} = Enum.find(styles1, &(elem(&1, 0) == selector)) || {"", []}
      {_, property_list2} = Enum.find(styles2, &(elem(&1, 0) == selector)) || {"", []}
      property_list = merge_property_lists(property_list1, property_list2)

      [{selector, property_list} | acc]
    end)
    |> Enum.reverse()
  end

  defp merge_property_lists(property_list1, property_list2) do
    Enum.reduce(property_list1 ++ property_list2, [], fn {property, value}, acc ->
      index =
        Enum.find_index(acc, fn
          {^property, _} -> true
          _ -> false
        end)

      if index do
        List.replace_at(acc, index, {property, value})
      else
        [{property, value} | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Scopes styles under an additional selector.

  ## Usage
      iex> styles = [{"div", [{"border", "1px solid"}]}, {"a.class", [{"color", "blue"}]}]
      iex> Keila.Templates.Css.scope(styles, "#foo")
      [{"#foo div", [{"border", "1px solid"}]}, {"#foo a.class", [{"color", "blue"}]}]
  """
  @spec scope(t(), String.t()) :: t()
  def scope(styles, scope) do
    Enum.map(styles, fn {selector, property_list} ->
      {scope <> " " <> selector, property_list}
    end)
  end

  @doc """
  Returns the value of the given `property` for the given `selector`in the
  provided  `styles`. Returns `nil` if the property could not be cound.
  """
  @spec get_value(t(), String.t(), String.t()) :: String.t() | nil
  def get_value(styles, selector, property) do
    case Enum.find(styles, &(elem(&1, 0) == selector)) do
      {_selector, property_list} ->
        Enum.find_value(property_list, &if(elem(&1, 0) == property, do: elem(&1, 1)))

      nil ->
        nil
    end
  end
end

defmodule Keila.Templates.Css.Parser do
  @moduledoc false
  import NimbleParsec

  @whitespace [?\s, ?\t, ?\n]

  insignificant_whitespace =
    ascii_string(@whitespace, min: 1)
    |> ignore()
    |> optional()

  name = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 1)

  universal_selector = string("*")
  type_selector = name
  class_selector = string(".") |> concat(name)
  id_selector = string("#") |> concat(name)
  # TODO attribute selectors

  basic_selector =
    choice([
      universal_selector,
      type_selector,
      class_selector,
      id_selector
    ])

  basic_combinator =
    insignificant_whitespace
    |> concat(ascii_string([?+, ?~, ?>], 1))
    |> concat(insignificant_whitespace)

  descendant_combinator =
    ascii_string(@whitespace, 1)
    |> concat(insignificant_whitespace)
    |> lookahead(basic_selector)

  combinator =
    choice([
      basic_combinator,
      descendant_combinator
    ])

  selector =
    basic_selector
    |> concat(
      repeat(
        optional(combinator)
        |> concat(basic_selector)
      )
    )
    |> tag(:selector)

  selector_list =
    selector
    |> repeat(
      insignificant_whitespace
      |> ignore(ascii_string([?,], 1))
      |> concat(insignificant_whitespace)
      |> concat(selector)
    )
    |> tag(:selector_list)

  property =
    ascii_string([?a..?z, ?A..?Z, ?-], min: 1)
    |> tag(:property)

  value =
    ascii_string(
      [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?#, ?., ?\s, ?', ?", ?%, ?,, ?), ?(, ?:, ?/, ?=, ??, ?&],
      min: 1
    )
    |> map({String, :trim_trailing, []})
    |> tag(:value)

  property_value =
    insignificant_whitespace
    |> concat(property)
    |> ignore(string(":"))
    |> concat(insignificant_whitespace)
    |> concat(value)

  property_list =
    insignificant_whitespace
    |> ignore(string("{"))
    |> optional(property_value)
    |> repeat(
      ignore(string(";"))
      |> concat(property_value)
    )
    |> optional(ignore(string(";")))
    |> concat(insignificant_whitespace)
    |> ignore(string("}"))
    |> tag(:property_list)

  css =
    times(
      selector_list |> concat(property_list) |> concat(insignificant_whitespace),
      min: 1
    )

  defparsec(:parse, css)
end
