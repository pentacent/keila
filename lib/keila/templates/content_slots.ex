defmodule Keila.Templates.ContentSlots do
  @moduledoc """
  Slot extraction and substitution for templates and campaigns.

  Supports three modes, set via the `:mode` option:

    * `:mjml` — slots must be direct children of `<mj-body>`; handled by
      `Keila.Templates.ContentSlots.Mjml`.
    * `:html` — slots can appear anywhere in the document.
    * `:text` — slots are matched with a regex; single line breaks after the opening
    * tag or before the closing tag are stripped.

  Extracted default content is tidied (dedented, surrounding blank lines removed)
  because it seeds a new campaign's editor; merged content is kept verbatim.
  """

  alias Keila.Templates.Slot
  alias Keila.Templates.ContentSlots.Mjml

  @doc """
  Returns the list of content slot definitions in the given input.

  Options:
    * `:mode` (required) — `:mjml`, `:html`, or `:text`.
  """
  @spec get_content_slots(String.t() | nil, keyword()) :: [Slot.t()]
  def get_content_slots(nil, _opts), do: []

  def get_content_slots(input, opts) when is_binary(input) do
    case Keyword.get(opts, :mode) do
      :mjml -> Mjml.get_slots(input)
      _other -> slots_from_regex(input)
    end
    |> Enum.map(&tidy_slot/1)
  end

  @doc """
  Merges a map of named content slots into the given input.
  Blank content values (`nil` or whitespace-only strings) are ignored.

  Options:
    * `:mode` (required) — `:mjml`, `:html`, or `:text`.
  """
  @spec merge_content_slots(String.t() | nil, map() | nil, keyword()) :: String.t() | nil
  def merge_content_slots(input, content, opts \\ [])
  def merge_content_slots(nil, _content, _opts), do: nil

  def merge_content_slots(input, content, opts) when is_binary(input) do
    content =
      (content || %{})
      |> stringify_keys()
      |> Map.reject(&blank_slot?/1)

    case Keyword.get(opts, :mode) do
      :mjml -> Mjml.merge_slots(input, content)
      _other -> merge_with_regex(input, content)
    end
  end

  # A single line break adjacent to the opening or closing tag is stripped,
  # so authors can format `<keila-content name="x">\nhello\n</keila-content>`
  # without the surrounding line breaks ending up in the rendered output.
  @slot_regex ~r{<keila-content\s+name\s*=\s*["']?([^"'\s>/]+)["']?[^>]*>\r?\n?(.*?)\r?\n?</keila-content>}s

  defp merge_with_regex(input, content) do
    Regex.replace(@slot_regex, input, fn _full, name, default ->
      Map.get(content, name, default)
    end)
  end

  defp slots_from_regex(input) do
    @slot_regex
    |> Regex.scan(input)
    |> Enum.map(fn [_full, name, default] ->
      %Slot{name: name, default_content: default}
    end)
  end

  defp tidy_slot(%Slot{default_content: content} = slot) do
    %{slot | default_content: tidy_default_content(content)}
  end

  defp tidy_default_content(content) do
    content
    |> String.split("\n")
    |> dedent()
    |> Enum.join("\n")
    |> String.trim()
  end

  defp dedent(lines) do
    indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&(Regex.run(~r/^[ \t]*/, &1) |> hd() |> byte_size()))
      |> Enum.min(fn -> 0 end)

    Enum.map(lines, fn line ->
      if String.trim(line) == "",
        do: "",
        else: binary_part(line, indent, byte_size(line) - indent)
    end)
  end

  defp blank_slot?({_name, nil}), do: true
  defp blank_slot?({_name, content}) when is_binary(content), do: String.trim(content) == ""
  defp blank_slot?(_slot), do: false

  defp stringify_keys(values) when is_map(values) do
    Enum.into(values, %{}, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      pair -> pair
    end)
  end
end
