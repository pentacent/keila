defmodule KeilaWeb.Gettext do
  defmacro __using__(__opts) do
    quote do
      use Gettext, backend: KeilaWeb.Gettext.Backend
      import KeilaWeb.Gettext.MarkdownHelpers
    end
  end

  def available_locales() do
    [
      {"English", "en"},
      {"Deutsch", "de"},
      {"Español", "es"},
      {"Français", "fr"},
      {"Italiano", "it"},
      {"Magyar", "hu"},
      {"Български", "bg"}
    ]
  end
end
