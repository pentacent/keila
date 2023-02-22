defmodule Keila.Templates.HtmlTextExtractor do
  @doc """
  Processes an HTML fragment tree and returns it as a string.
  """
  @spec extract_text(Keila.Templates.Html.t(), String.t()) :: String.t()
  def extract_text(html, selector \\ "body") do
    Floki.find(html, selector)
    |> do_extract_text(0)
    |> concat_extracted_text()
    |> then(fn string -> string <> "\n" end)
  end

  defp do_extract_text(html, list_level) when is_list(html) do
    Enum.map(html, &do_extract_text(&1, list_level))
  end

  defp do_extract_text({"br", _, _}, _), do: ["\n"]

  defp do_extract_text({"ul", _, content}, list_level) do
    content
    |> Enum.filter(&match?({"li", _, _}, &1))
    |> Enum.map(fn {"li", _attrs, content} ->
      indentation = String.pad_trailing("", (list_level + 1) * 2, " ")

      text_content =
        content
        |> do_extract_text(list_level + 1)
        |> concat_extracted_text()
        |> String.replace(~r{\n(\w)}, "\n#{indentation}\\g{1}")

      ["- ", text_content, "\n"]
    end)
    |> then(fn content -> ["\n" | content] end)
  end

  defp do_extract_text({"ol", _attrs, content}, list_level) do
    content
    |> Enum.filter(&match?({"li", _, _}, &1))
    |> Enum.with_index()
    |> Enum.map(fn {{"li", _attrs, content}, i} ->
      indentation = String.pad_trailing("", (list_level + 1) * 2, " ")

      text_content =
        content
        |> do_extract_text(list_level + 1)
        |> concat_extracted_text()
        |> String.replace(~r{\n(\w)}, "\n#{indentation}\\g{1}")

      ["#{i + 1}. ", text_content, "\n"]
    end)
    |> then(fn content -> ["\n" | content] end)
  end

  defp do_extract_text({"h" <> level, _, content}, list_level)
       when level in ["1", "2", "3", "4", "5"] do
    padding =
      level |> String.to_integer() |> then(fn n -> String.pad_trailing("", n, "#") <> " " end)

    [padding | do_extract_text(content, list_level) ++ ["\n"]]
  end

  defp do_extract_text({"hr", _attrs, _content}, _list_level) do
    "\n---\n\n"
  end

  defp do_extract_text({"a", attrs, content}, list_level) do
    href = html_attribute(attrs, "href")
    title = html_attribute(attrs, "title")
    content = do_extract_text(content, list_level)

    case title do
      nil -> ["[", content, "]", "(#{href})"]
      title -> ["[", content, "]", ~s{(#{href} "#{title}")}]
    end
  end

  defp do_extract_text({"blockquote", _attrs, content}, list_level) do
    content =
      content
      |> do_extract_text(list_level)
      |> concat_extracted_text()
      |> String.replace(~r{\n|^(\w)}, "\n> \\g{1}")

    ["\n", content]
  end

  defp do_extract_text({_tag, _ttrs, content}, list_level) do
    do_extract_text(content, list_level)
  end

  defp do_extract_text(text, _) when is_binary(text) do
    whitespace_left = if String.match?(text, ~r{^\s}), do: :whitespace
    whitespace_right = if String.match?(text, ~r{\s$}), do: :whitespace

    [whitespace_left, String.trim(text), whitespace_right]
  end

  defp concat_extracted_text(list) do
    list
    |> List.flatten()
    |> Enum.drop_while(&(is_nil(&1) or &1 == :whitespace))
    |> Enum.reverse()
    |> Enum.drop_while(&(is_nil(&1) or &1 == :whitespace))
    |> Enum.reduce([], fn el, acc ->
      cond do
        el == :whitespace and Enum.empty?(acc) ->
          []

        el == :whitespace and hd(acc) == :whitespace ->
          acc

        el == :whitespace and String.ends_with?(hd(acc), "\n") ->
          acc

        is_nil(el) ->
          acc

        is_binary(el) and not Enum.empty?(acc) and hd(acc) == :whitespace and
            String.ends_with?(el, "\n") ->
          List.replace_at(acc, 0, el)

        true ->
          [el | acc]
      end
    end)
    |> Enum.map(fn
      :whitespace -> " "
      text -> text
    end)
    |> Enum.join("")
    |> String.replace("\n\n\n", "\n\n")
  end

  defp html_attribute(attrs, name) do
    Enum.find_value(attrs, "", fn
      {^name, value} -> value
      _other -> nil
    end)
  end
end
