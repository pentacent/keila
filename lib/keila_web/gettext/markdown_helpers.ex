defmodule KeilaWeb.Gettext.MarkdownHelpers do
  @moduledoc """
  Module with convenience macros for translating and rendering markdown content.
  """

  @doc """
  Convenience macro for translating Markdown strings. Returns `{:safe, html}`.
  """
  defmacro gettext_md(msgid, bindings \\ Macro.escape(%{})) do
    quote do
      gettext(unquote(msgid), unquote(bindings))
      |> Earmark.as_html!()
      |> then(fn html -> {:safe, html} end)
    end
  end

  @doc """
  Convenience macro for translating Markdown strings while specifying a domain.

  Returns `{:safe, html}`.
  """
  defmacro dgettext_md(domain, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      dgettext(unquote(domain), unquote(msgid), unquote(bindings))
      |> Earmark.as_html!()
      |> then(fn html -> {:safe, html} end)
    end
  end
end
