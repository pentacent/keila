defmodule KeilaWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      import KeilaWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext, otp_app: :keila, default_locale: "en", priv: "priv/gettext"

  @doc """
  Convenience macro for translating Markdown strings. Returns `{:safe, html}`.
  """
  defmacro gettext_md(msgid, bindings \\ Macro.escape(%{})) do
    domain = __gettext__(:default_domain)

    quote do
      unquote(__MODULE__).dpgettext(unquote(domain), nil, unquote(msgid), unquote(bindings))
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
      unquote(__MODULE__).dpgettext(unquote(domain), nil, unquote(msgid), unquote(bindings))
      |> Earmark.as_html!()
      |> then(fn html -> {:safe, html} end)
    end
  end

  def available_locales() do
    [
      {"English", "en"},
      {"Deutsch", "de"},
      {"Français", "fr"},
      {"Español", "es"},
      {"Magyar", "hu"},
      {"Български", "bg"}
    ]
  end
end
