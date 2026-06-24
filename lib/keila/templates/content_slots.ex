defmodule Keila.Templates.ContentSlots do
  @moduledoc """
  Slot extraction and substitution for templates and campaigns.

  Supports three modes, set via the `:mode` option:

    * `:mjml` — slots must be direct children of `<mj-body>`.
    * `:html` — slots can appear anywhere in the document.
    * `:text` — slots are matched with a regex; single line breaks after the opening
    * tag or before the closing tag are stripped.
  """

  alias Keila.Templates.Slot

  # A single line break adjacent to the opening or closing tag is stripped,
  # so authors can format `<keila-content name="x">\nhello\n</keila-content>`
  # without the surrounding line breaks ending up in the rendered output.
  @slot_regex ~r{<keila-content\s+name\s*=\s*"([^"]+)"[^>]*>\r?\n?(.*?)\r?\n?</keila-content>}s

  @doc """
  Returns the list of content slot definitions in the given input.

  Options:
    * `:mode` (required) — `:mjml`, `:html`, or `:text`.
  """
  @spec get_content_slots(String.t() | nil, keyword()) :: [Slot.t()]
  def get_content_slots(nil, _opts), do: []

  def get_content_slots(input, opts) when is_binary(input) do
    case Keyword.fetch!(opts, :mode) do
      :mjml -> get_slots_from_tree(input, "mj-body > keila-content")
      :html -> get_slots_from_tree(input, "keila-content")
      :text -> get_slots_from_regex(input)
    end
  end

  defp get_slots_from_regex(input) do
    @slot_regex
    |> Regex.scan(input)
    |> Enum.map(fn [_full, name, default] ->
      %Slot{name: name, default_content: default}
    end)
  end

  defp get_slots_from_tree(input, selector) do
    input = input |> stash_mj_head() |> stash_liquid()

    with {:ok, tree} <- Floki.parse_fragment(input) do
      tree
      |> Floki.find(selector)
      |> Enum.map(fn {_tag, attrs, children} ->
        name = attr_value(attrs, "name")

        if is_binary(name) and name != "" do
          content = children |> Floki.raw_html(pretty: true) |> restore_liquid()
          %Slot{name: name, default_content: content}
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end

  @doc """
  Merges a map of named content slots into the given input.

  Options:
    * `:mode` (required) — `:mjml`, `:html`, or `:text`.
    * `:pretty` — output is prettified when set to `true` (`:mjml` and `:html` only).
  """
  @spec merge_content_slots(String.t() | nil, map() | nil, keyword()) :: String.t() | nil
  def merge_content_slots(input, content, opts \\ [])
  def merge_content_slots(nil, _content, _opts), do: nil

  def merge_content_slots(input, content, opts) when is_binary(input) do
    case Keyword.fetch!(opts, :mode) do
      :mjml -> merge_content_slots_with_tree(input, content, &fill_mjml_slots/2, opts)
      :html -> merge_content_slots_with_tree(input, content, &fill_html_slots/2, opts)
      :text -> merge_content_slots_with_regex(input, content)
    end
  end

  defp merge_content_slots_with_regex(input, content) do
    content = stringify_keys(content || %{})

    Regex.replace(@slot_regex, input, fn _full, name, default ->
      Map.get(content, name, default)
    end)
  end

  defp merge_content_slots_with_tree(input, content, traverse_fun, opts) do
    input = input |> stash_mj_head() |> stash_liquid()

    content =
      (content || %{})
      |> stringify_keys()
      |> Enum.map(fn {key, value} -> {key, stash_liquid(value)} end)
      |> Enum.into(%{})

    with {:ok, tree} <- Floki.parse_fragment(input) do
      tree
      |> Floki.traverse_and_update(&traverse_fun.(&1, content))
      |> Floki.raw_html(pretty: opts[:pretty] || false)
      |> restore_liquid()
      |> restore_mj_head()
    else
      _ -> input |> restore_liquid() |> restore_mj_head()
    end
  end

  # In MJML, slots may only be direct children of <mj-body>, so we fill slots
  # only in that element's children and leave the rest of the tree untouched.
  defp fill_mjml_slots({"mj-body", attrs, children}, content) when is_list(children),
    do: {"mj-body", attrs, Enum.flat_map(children, &maybe_merge_content_slot(&1, content))}

  defp fill_mjml_slots(other, _),
    do: other

  defp fill_html_slots({tag, attrs, children}, content) when is_list(children),
    do: {tag, attrs, Enum.flat_map(children, &maybe_merge_content_slot(&1, content))}

  defp fill_html_slots(other, _),
    do: other

  defp maybe_merge_content_slot({"keila-content", attrs, default_content}, content) do
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

  defp maybe_merge_content_slot(other, _), do: [other]

  defp try_parse_fragment(value, fallback) when is_binary(value) do
    case Floki.parse_fragment(value) do
      {:ok, tree} -> tree
      _ -> fallback
    end
  end

  defp try_parse_fragment(_value, fallback), do: fallback

  # ---- liquid stashing -------------------------------------------------------

  # Wraps each Liquid expression in a base64-encoded placeholder so Floki's
  # default HTML encoding can't corrupt `"`, `<`, `>`, `&` inside it.
  defp stash_liquid(input) when is_binary(input) do
    Regex.replace(~r/\{[\{%].*?[\}%]\}/s, input, fn liquid ->
      "__KEILA_LIQUID--#{Base.encode64(liquid)}__"
    end)
  end

  defp stash_liquid(nil), do: nil

  defp restore_liquid(input) do
    Regex.replace(~r{__KEILA_LIQUID--([A-Za-z0-9+/=]+)__}, input, fn full, liquid_base64 ->
      case Base.decode64(liquid_base64) do
        {:ok, decoded} -> decoded
        :error -> full
      end
    end)
  end

  # Lexbor is strictly HTML5-compliant and doesn't allow custom self-closing tags.
  # However, MJML requires self-closing tags in mj-attributes.
  # Since slots can only live in mj-body anyways, we stash mj-head and restore it
  # verbatim.
  defp stash_mj_head(input) when is_binary(input) do
    Regex.replace(~r{<mj-head\b[^>]*>.*?</mj-head>}s, input, fn head ->
      "__KEILA_MJ_HEAD--#{Base.encode64(head)}__"
    end)
  end

  defp restore_mj_head(input) do
    Regex.replace(~r{__KEILA_MJ_HEAD--([A-Za-z0-9+/=]+)__}, input, fn full, head_base64 ->
      case Base.decode64(head_base64) do
        {:ok, decoded} -> decoded
        :error -> full
      end
    end)
  end

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
