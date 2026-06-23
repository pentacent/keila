defmodule KeilaWeb.ApiTemplateView do
  use KeilaWeb, :view
  alias Keila.Pagination
  alias Keila.Templates

  def render("templates.json", %{templates: templates = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => templates.page,
        "page_count" => templates.page_count,
        "count" => templates.count
      },
      "data" => Enum.map(templates.data, &template_data/1)
    }
  end

  def render("template.json", %{template: template}) do
    %{
      "data" => template_data(template)
    }
  end

  @properties [
    :id,
    :name,
    :type,
    :mjml_body,
    :html_body,
    :text_body,
    :styles,
    :assigns,
    :inserted_at,
    :updated_at
  ]
  defp template_data(template) do
    template
    |> Map.take(@properties)
    |> maybe_put_content_slots(template)
  end

  defp maybe_put_content_slots(json, template = %{type: type})
       when type in [:mjml, :html, :text] do
    slots =
      template
      |> Map.get(:"#{type}_body")
      |> Templates.get_content_slots(mode: template.type)
      |> Enum.map(&slot_data/1)

    Map.put(json, :"#{type}_content_slots", slots)
  end

  defp maybe_put_content_slots(json, _template), do: json

  defp slot_data(slot), do: Map.take(slot, [:name, :default_content])
end
