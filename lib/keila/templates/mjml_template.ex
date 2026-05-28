defmodule Keila.Templates.MjmlTemplate do
  @moduledoc """
  Helper module for handling MJML templates.
  """

  defmodule Slot do
    @moduledoc """
    A parsed keila-content slot definition: the slot's `name` and its `default_content`
    """

    @enforce_keys [:name, :default_content]
    defstruct [:name, :default_content]

    @type t :: %__MODULE__{name: String.t(), default_content: String.t() | nil}
  end

  @doc """
  Removes `<keila-code>` wrapper tags from an MJML document, leaving
  their contents in place.
  This is necessary to avoid special characters inside of Liquid tags
  from being escaped when parsing the document.
  """
  @spec remove_code_blocks(String.t() | nil) :: String.t() | nil
  def remove_code_blocks(nil), do: nil

  def remove_code_blocks(mjml) when is_binary(mjml) do
    String.replace(mjml, ~r{</?keila-code\s*/?>}, "")
  end

  @doc """
  Returns the list of content slot definitions in an MJML document.
  """
  @spec get_content_slots(String.t() | nil) :: [Slot.t()]
  def get_content_slots(nil), do: []

  def get_content_slots(mjml) when is_binary(mjml) do
    {mjml, liquid_tags} = stash_liquid(mjml)

    with {:ok, tree} <- Floki.parse_fragment(mjml) do
      tree
      |> Floki.find("mj-body > keila-content")
      |> Enum.map(fn {_tag, attrs, children} ->
        name = attr_value(attrs, "name")

        if is_binary(name) and name != "" do
          content = children |> Floki.raw_html(pretty: true) |> restore_liquid(liquid_tags)
          %Slot{name: name, default_content: content}
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end

  @doc """
  Merges a map of named content slots into the given MJML.

  Options:
    * `:pretty` - output is prettified when set to `true`.
  """
  @spec merge_content_slots(String.t() | nil, map() | nil, keyword()) :: String.t() | nil
  def merge_content_slots(mjml, content, opts \\ [])
  def merge_content_slots(nil, _content, _opts), do: nil

  def merge_content_slots(mjml, content, opts) when is_binary(mjml) do
    {mjml, liquid_tags} = stash_liquid(mjml)
    content = stringify_keys(content || %{})

    with {:ok, tree} <- Floki.parse_fragment(mjml) do
      tree
      |> Floki.traverse_and_update(fn
        {"mj-body", attrs, children} ->
          updated_children = Enum.flat_map(children, &maybe_merge_content_slot(&1, content))
          {"mj-body", attrs, updated_children}

        other ->
          other
      end)
      |> Floki.raw_html(pretty: opts[:pretty] || false)
      |> restore_liquid(liquid_tags)
    else
      _ -> mjml
    end
  end

  # This is necessary because otherwise parsing and serializing the HTML breaks special characters inside Liquid tags.
  defp stash_liquid(mjml) do
    expressions =
      ~r/\{[\{%].*?[\}%]\}/s
      |> Regex.scan(mjml)
      |> Enum.map(fn [match] -> match end)
      |> Enum.uniq()

    base = :rand.uniform(900_000_000) + 1_000_000_000

    expressions
    |> Enum.with_index()
    |> Enum.reduce({mjml, %{}}, fn {expr, i}, {acc, map} ->
      placeholder = "__KEILA_LIQUID--#{base + i}__"
      {String.replace(acc, expr, placeholder), Map.put(map, placeholder, expr)}
    end)
  end

  defp restore_liquid(mjml, liquid_tags) do
    Enum.reduce(liquid_tags, mjml, fn {placeholder, expr}, acc ->
      String.replace(acc, placeholder, expr)
    end)
  end

  defp maybe_merge_content_slot({"keila-content", attrs, children}, content),
    do: merge_content_slot(attrs, children, content)

  defp maybe_merge_content_slot(other, _), do: [other]

  defp merge_content_slot(attrs, default_content, content) do
    name =
      case attr_value(attrs, "name") do
        name when is_binary(name) and name != "" -> name
        _ -> nil
      end

    if not is_nil(name) and Map.has_key?(content, name) do
      try_parse_fragment(content[name], default_content)
    else
      default_content
    end
  end

  defp try_parse_fragment(value, fallback) when is_binary(value) do
    case Floki.parse_fragment(value) do
      {:ok, tree} -> tree
      _ -> fallback
    end
  end

  defp try_parse_fragment(_value, fallback), do: fallback

  defp attr_value(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {^name, value} -> value
      _ -> nil
    end
  end

  defp stringify_keys(values) when is_map(values) do
    Enum.into(values, %{}, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      pair -> pair
    end)
  end
end
