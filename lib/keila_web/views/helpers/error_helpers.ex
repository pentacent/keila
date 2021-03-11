defmodule KeilaWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def with_validation(form, field, [{:do, content}]) do
    case get_errors(form, field) do
      [] ->
        [content]

      errors ->
        [
          content_tag(:span, nil, class: "form-error-indicator"),
          content,
          content_tag(:p, class: "form-errors") do
            errors
          end
        ]
    end
  end

  @doc """
  Generates a tag only if there is a form/changeset error.
  """
  def with_errors(form, field, [{:do, content}]) do
    case get_errors(form, field) do
      [] ->
        []

      errors ->
        [
          content,
          content_tag(:p, class: "form-errors") do
            errors
          end
        ]
    end
  end

  defp get_errors(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error), class: "invalid-feedback")
    end)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(KeilaWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(KeilaWeb.Gettext, "errors", msg, opts)
    end
  end
end
