defmodule Keila.Templates.ContentSlots.Mjml do
  @moduledoc """
  MJML-specific slot handling for `Keila.Templates.ContentSlots`.

  In MJML, slots must be the direct children of `<mj-body>`. MJML is not valid
  HTML (self-closing custom tags, raw `<mj-table>` rows, an XML-ish `<mj-head>`,
  embedded Liquid), so it can't be round-tripped through an HTML parser without
  corruption. Instead, a small scanner walks the `<mj-body>` content token by
  token, tracking element nesting depth, and locates each direct-child
  `<keila-content>` by its byte span — everything else is preserved verbatim.

  `get_slots/1` returns the raw inner content; the caller
  (`Keila.Templates.ContentSlots`) tidies it for display.
  """

  alias Keila.Templates.Slot

  @mjml_token_regex ~r{
      \{[\{%].*?[\}%]\}
    | <!--.*?-->
    | </[a-zA-Z][\w:-]*\s*>
    | <[a-zA-Z][\w:-]*(?:"[^"]*"|'[^']*'|[^>"'])*?/>
    | <[a-zA-Z][\w:-]*(?:"[^"]*"|'[^']*'|[^>"'])*?>
  }sx

  @mj_body_regex ~r{(<mj-body\b[^>]*>)(.*)(</mj-body>)}s
  @slot_open_regex ~r/\A<keila-content(?:\s|>)/
  @slot_close_regex ~r{\A</keila-content\s*>\z}
  @slot_name_regex ~r/\sname\s*=\s*["']?([^"'\s>\/]+)["']?/
  @tag_name_regex ~r/\A<([a-zA-Z][\w:-]*)/
  @void_elements ~w(area base br col embed hr img input link meta param source track wbr)

  @doc """
  Returns the direct-child `<keila-content>` slots of `<mj-body>`, in document
  order. `default_content` is the raw inner content; the caller tidies it.
  """
  @spec get_slots(String.t()) :: [Slot.t()]
  def get_slots(input) do
    input
    |> mj_body_inner()
    |> slot_spans()
    |> Enum.flat_map(&to_slot/1)
  end

  @doc """
  Replaces each direct-child slot of `<mj-body>` with its value from `content`,
  falling back to the slot's own default content. Everything outside the slots
  (including `<mj-head>` and the surrounding markup) is preserved verbatim.
  """
  @spec merge_slots(String.t(), map()) :: String.t()
  def merge_slots(input, content) do
    Regex.replace(@mj_body_regex, input, fn _full, open_tag, inner, close_tag ->
      filled = fill_spans(inner, slot_spans(inner), content)
      open_tag <> filled <> close_tag
    end)
  end

  defp mj_body_inner(input) do
    case Regex.run(@mj_body_regex, input, capture: :all_but_first) do
      [_open, inner, _close] -> inner
      _ -> ""
    end
  end

  defp to_slot(%{name: name, content: content}) when is_binary(name) and name != "",
    do: [%Slot{name: name, default_content: content}]

  defp to_slot(_span), do: []

  # Returns byte-spans of <keila-content> tags at the root level of the given fragment
  defp slot_spans(fragment) do
    {spans, _depth, _open} =
      @mjml_token_regex
      |> Regex.scan(fragment, return: :index)
      |> Enum.reduce({[], 0, nil}, &scan_token(fragment, &1, &2))

    Enum.reverse(spans)
  end

  defp scan_token(fragment, [{offset, length}], {spans, depth, open}) do
    token = binary_part(fragment, offset, length)

    cond do
      liquid?(token) ->
        {spans, depth, open}

      comment?(token) ->
        {spans, depth, open}

      depth == 0 && is_nil(open) && self_closed_slot?(token) ->
        {[empty_slot_span(token, offset, length) | spans], depth, open}

      depth == 0 && is_nil(open) && slot_open?(token) ->
        {spans, 1, open_slot(token, offset, length)}

      depth == 1 && open && slot_close?(token) ->
        close_slot(spans, fragment, offset, length, open)

      self_closing?(token) ->
        {spans, depth, open}

      closing_tag?(token) ->
        {spans, max(depth - 1, 0), open}

      void_element?(token) ->
        {spans, depth, open}

      true ->
        {spans, depth + 1, open}
    end
  end

  defp liquid?(token), do: String.starts_with?(token, "{")

  defp self_closing?(token), do: String.ends_with?(token, "/>")

  defp closing_tag?(token), do: String.starts_with?(token, "</")

  defp slot_open?(token), do: Regex.match?(@slot_open_regex, token)

  defp slot_close?(token), do: Regex.match?(@slot_close_regex, token)

  defp self_closed_slot?(token), do: self_closing?(token) and slot_open?(token)

  defp comment?(token), do: String.starts_with?(token, "<!--")

  defp void_element?(token) do
    case Regex.run(@tag_name_regex, token) do
      [_full, name] -> String.downcase(name) in @void_elements
      nil -> false
    end
  end

  defp open_slot(token, offset, length),
    do: %{name: slot_name(token), start: offset, content_start: offset + length}

  defp empty_slot_span(token, offset, length),
    do: %{name: slot_name(token), content: "", start: offset, stop: offset + length}

  # A </keila-content> only closes the open slot when it brings the depth back to
  # 0 — a nested </keila-content> sits at depth > 0 and is part of the content.
  defp close_slot(spans, fragment, offset, length, open) do
    span = %{
      name: open.name,
      content: binary_part(fragment, open.content_start, offset - open.content_start),
      start: open.start,
      stop: offset + length
    }

    {[span | spans], 0, nil}
  end

  defp fill_spans(fragment, spans, content) do
    {chunks, cursor} =
      Enum.map_reduce(spans, 0, fn span, cursor ->
        preceding = binary_part(fragment, cursor, span.start - cursor)
        {[preceding, fill_span(span, content)], span.stop}
      end)

    tail = binary_part(fragment, cursor, byte_size(fragment) - cursor)
    IO.iodata_to_binary([chunks, tail])
  end

  defp fill_span(%{name: name, content: content}, slot_content)
       when is_binary(name) and name != "" do
    Map.get(slot_content, name, trim_linebreaks(content))
  end

  # A nameless <keila-content> is not a slot; unwrap it to its inner content.
  defp fill_span(%{content: content}, _slot_content), do: content

  defp slot_name(token) do
    case Regex.run(@slot_name_regex, token, capture: :all_but_first) do
      [name] -> name
      nil -> nil
    end
  end

  defp trim_linebreaks(content) do
    content
    |> then(&Regex.replace(~r/\A(?:\r\n|\r|\n)/, &1, "", global: false))
    |> then(&Regex.replace(~r/(?:\r\n|\r|\n)\z/, &1, "", global: false))
  end
end
