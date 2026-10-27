defmodule KeilaWeb.Gettext do
  defmacro __using__(__opts) do
    quote do
      use Gettext, backend: KeilaWeb.Gettext.Backend
      import KeilaWeb.Gettext.MarkdownHelpers
    end
  end

  @doc """
  List of available locales and their native name.
  Ordered alphabetically for Latin-script languages,
  then ordered by language code for non-Latin scripts. 
  """
  def available_locales() do
    [
      {"English", "en"},
      {"Deutsch", "de"},
      {"Español", "es"},
      {"Français", "fr"},
      {"Italiano", "it"},
      {"Magyar", "hu"},
      {"Português (Brasil)", "pt_BR"},
      {"Svenska", "sv"},
      {"Български", "bg"}
    ]
  end
end
