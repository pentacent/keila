defmodule KeilaWeb.EmailDialogView do
  use KeilaWeb, :view
  import Ecto.Changeset, only: [get_field: 2]

  defp type_options() do
    [
      {gettext("Markdown"), "markdown"},
      {gettext("Text only"), "text"},
      {gettext("MJML"), "mjml"},
      {gettext("HTML"), "html"}
    ]
  end

  def compatible_templates(templates, type) do
    template_types =
      case type do
        :markdown -> [:hybrid]
        :text -> [:text]
        :mjml -> [:mjml]
        :html -> [:html]
        _other -> []
      end

    Enum.filter(templates, &(&1.type in template_types))
  end

  defp template_options(templates, type) do
    options =
      for template <- compatible_templates(templates, type), do: {template.name, template.id}

    [{gettext("Default"), nil} | options]
  end

  defp body_field(:html), do: :html_body
  defp body_field(:mjml), do: :mjml_body
  defp body_field(_markdown_or_text), do: :text_body
end
