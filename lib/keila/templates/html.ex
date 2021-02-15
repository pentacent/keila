defmodule Keila.Templates.Html do
  @moduledoc """
  Module for handling and manipulating HTML.

  ## Parsing HTML
  This module uses Floki to parse HTML documents and fragments.
  Within Keila, the use of the functions of this module is encouraged over invoking
  Floki directly.

  ## Limiting allowed HTML tags and attributes
  Use `restrict/2` to produce sanitized HTML from user input.

  ## Applying inline styles
  Use `apply_inline_styles/2` to inline CSS styles.
  """

  alias Keila.Templates.Css

  @type t :: Floki.html_tree()

  @doc """
  Parses a HTML document and returns an HTML tree,
  """
  @spec parse_document!(String.t()) :: t()
  def parse_document!(html) do
    Floki.parse_document!(html)
  end

  @doc """
  Parses an HTML fragment (i.e. an incomplete HTML document) and returns an HTML tree.
  """
  @spec parse_fragment!(String.t()) :: t()
  def parse_fragment!(html) do
    Floki.parse_fragment!(html)
  end

  @doc """
  Processes an HTML document tree and returns it as a string.
  """
  @spec to_document(t()) :: String.t()
  def to_document(html_tree) do
    Floki.raw_html(html_tree)
  end

  @doc """
  Processes an HTML fragment tree and returns it as a string.
  """
  @spec to_fragment(t()) :: String.t()
  def to_fragment(html_tree) do
    Floki.raw_html(html_tree)
  end

  @allowed_tags ~w(h1 h2 h3 h4 section[checked] div p span a[href] em strong ul li)
  @config Enum.map(@allowed_tags, fn tag ->
            case Regex.run(~r{(\w+)(?:\[([a-z0-9\-,]+)\])?}, tag) do
              [_, tag] -> {tag, []}
              [_, tag, attrs] -> {tag, String.split(attrs, ",")}
            end
          end)
          |> Enum.into(%{})

  @doc """
  Takes an HTML tree and removes tags and attributes that are not allowed by the
  specified `format`.
  Currently only one format is supported: `:limited`. It allows the following
  tags and attributes:

  `h1 h2 h3 h4 section[checked] div p span a[href] em strong ul li`

  ## Usage

      iex> "<script>evil()</script><p x-data='dangerous'>harmless</p>" \\
      iex> |> Keila.Templates.Html.parse_fragment!() \\
      iex> |> Keila.Templates.Html.restrict(:limited) \\
      iex> |> Keila.Templates.Html.to_fragment()
      "<p>harmless</p>"
  """
  @spec restrict(t(), :limited) :: t()
  def restrict(html_tree, :limited) do
    restrict_nodes(html_tree, @config)
  end

  defp restrict_nodes(children, config)

  defp restrict_nodes([], _config), do: []

  defp restrict_nodes(text, _config) when is_binary(text), do: text

  defp restrict_nodes(children, config) do
    children
    |> Enum.filter(fn node -> filter_node(node, config) end)
    |> Enum.map(fn node -> restrict_node(node, config) end)
  end

  defp filter_node({tag, _attrs, _children}, config) do
    tag in Map.keys(config)
  end

  defp filter_node(text_node, _config) when is_binary(text_node) do
    true
  end

  defp restrict_node({tag, attrs, children}, config) do
    attrs = Enum.filter(attrs, fn {attr, _} -> attr in Map.get(config, tag) end)
    children = restrict_nodes(children, config)
    {tag, attrs, children}
  end

  defp restrict_node(text, _config) when is_binary(text) do
    text
  end

  @doc """
  Takes an HTML tree and a CSS list and applies the CSS styles as inline styles.

  ## Usage

      iex> css_list = Keila.Templates.Css.parse!("span {color: blue}")
      iex> "<span>foo</span>" \\
      iex> |> Keila.Templates.Html.parse_fragment!() \\
      iex> |> Keila.Templates.Html.apply_inline_styles(css_list) \\
      iex> |> Keila.Templates.Html.to_fragment()
      ~s{<span style="color:blue">foo</span>}
  """
  @spec apply_inline_styles(t(), Css.t()) :: t()
  def apply_inline_styles(html, css_list) do
    css_list
    |> Enum.reduce(html, fn {selector, styles}, html ->
      Floki.find_and_update(html, selector, fn {tag, attributes} ->
        attributes = put_inline_styles(attributes, styles)
        {tag, attributes}
      end)
    end)
  end

  defp put_inline_styles(attributes, styles) do
    styles =
      styles
      |> Enum.map(fn {key, value} -> "#{key}:#{value}" end)
      |> Enum.join(";")

    index = Enum.find_index(attributes, fn {attribute, _} -> attribute == "style" end)

    if index do
      List.update_at(attributes, index, fn {"style", existing_styles} ->
        {"style", existing_styles <> ";" <> styles}
      end)
    else
      attributes ++ [{"style", styles}]
    end
  end
end
