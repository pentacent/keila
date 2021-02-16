defmodule Keila.Templates.Css do
  @moduledoc """
  Module for handling CSS styles with simple CSS parser.

  The parser is based on the [MDN CSS specifications](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference)

  ## Usage

      iex> css = "div {border: 1px solid} a.class {text-decoration: underline; color: blue}"
      iex> Keila.Templates.Css.parse!(css)
      [{"div", [{"border", "1px solid"}]}, {"a.class", [{"text-decoration", "underline"}, {"color", "blue"}]}]
  """

  @type t :: list({String.t(), list({String.t(), String.t()})})

  @spec parse!(String.t()) :: t()
  def parse!(input) do
    {:ok, rules, _, _, _, _} = __MODULE__.Parser.parse(input)

    rules
    |> Enum.reduce([], fn
      {:selector, selector}, acc ->
        selector = to_string(selector)
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

  property =
    ascii_string([?a..?z, ?A..?Z, ?-], min: 1)
    |> tag(:property)

  value =
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?#, ?., ?\s, ?', ?", ?%], min: 1)
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
      selector |> concat(property_list) |> concat(insignificant_whitespace),
      min: 1
    )

  defparsec(:parse, css)
end
