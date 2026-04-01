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
      |> Earmark.as_html!(
        registered_processors: {"a", &KeilaWeb.Gettext.MarkdownHelpers.add_target/1}
      )
      |> then(fn html -> {:safe, html} end)
    end
  end

  def add_target(node) do
    if Earmark.AstTools.find_att_in_node(node, "href", "") =~ ~r/^https?:\/\// do
      Earmark.AstTools.merge_atts_in_node(node, target: "_blank")
    else
      node
    end
  end
end
