defmodule Keila.HtmlFormat do
  @doc """
  Module for limiting permissible HTML tags.

  ## Formats
  Currently only one format is supported: `:limited`. It allows the following
  tags and attributes:

  `h1 h2 h3 h4 section[checked] div p span a[href] em strong ul li`

  ## Usage

      iex> html = "<script>evil()</script><p x-data='dangerous'>harmless</p>"
      iex> Keila.HtmlFormat.format_html(html, :limited)
      "<p>harmless</p>"
  """

  @allowed_tags ~w(h1 h2 h3 h4 section[checked] div p span a[href] em strong ul li)
  @config Enum.map(@allowed_tags, fn tag ->
            case Regex.run(~r{(\w+)(?:\[([a-z0-9\-,]+)\])?}, tag) do
              [_, tag] -> {tag, []}
              [_, tag, attrs] -> {tag, String.split(attrs, ",")}
            end
          end)
          |> Enum.into(%{})

  @spec format_html(String.t(), :limited) :: String.t()
  def format_html(html, mode) do
    :limited = mode
    do_format(html, @config)
  end

  defp do_format(html, config) do
    config = config

    case Floki.parse_fragment(html) do
      {:ok, nodes} -> format_nodes(nodes, config)
      _ -> []
    end
    |> Floki.raw_html()
  end

  defp format_nodes(children, config)

  defp format_nodes([], _config), do: []

  defp format_nodes(text, _config) when is_binary(text), do: text

  defp format_nodes(children, config) do
    children
    |> Enum.filter(fn node -> filter_node(node, config) end)
    |> Enum.map(fn node -> format_node(node, config) end)
  end

  defp filter_node({tag, _attrs, _children}, config) do
    tag in Map.keys(config)
  end

  defp filter_node(text_node, _config) when is_binary(text_node) do
    true
  end

  defp format_node({tag, attrs, children}, config) do
    attrs = Enum.filter(attrs, fn {attr, _} -> attr in Map.get(config, tag) end)
    children = format_nodes(children, config)
    {tag, attrs, children}
  end

  defp format_node(text, _config) when is_binary(text) do
    text
  end
end
