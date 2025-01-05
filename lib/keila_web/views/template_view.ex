defmodule KeilaWeb.TemplateView do
  use KeilaWeb, :view
  import Ecto.Changeset, only: [get_field: 2]

  def render_css_form(form, field, css_rows) do
    Enum.map(css_rows, fn group -> render_group(form, field, group) end)
  end

  defp render_group(form, field, {group_label, rows}) do
    content_tag(:div, x_data: "{show: false}") do
      [
        content_tag(
          :h2,
          [
            group_label,
            content_tag(:span, render_icon(:chevron_down), class: "inline-flex ml-2 h-4 w-4")
          ],
          "@click": "show = !show",
          class: "font-bold flex items-center cursor-pointer select-none"
        ),
        content_tag(:div, render_input_rows(form, field, group_label, rows),
          "x-show.transition.origin.top": "show",
          class: "grid grid-cols-2 gap-x-2 gap-y-4 items-center"
        )
      ]
    end
  end

  defp render_input_rows(form, field, group_label, rows) do
    Enum.map(rows, fn row ->
      [render_label(form, field, group_label, row), render_input(form, field, group_label, row)]
    end)
  end

  defp render_label(form, field, group_label, row) do
    label =
      case row[:property] do
        "color" -> gettext("Text color")
        "background-color" -> gettext("Background")
        "background-image" -> gettext("Image")
        "font-family" -> gettext("Font")
        "font-style" -> gettext("Font style")
        "font-weight" -> gettext("Font weight")
        "text-decoration" -> gettext("Decoration")
        "border-style" -> gettext("Border style")
        "border-color" -> gettext("Border color")
        "opacity" -> gettext("Opacity")
        "margin" -> gettext("Margin")
        "text-align" -> gettext("Text alignment")
      end

    content_tag(:label, label, for: input_name(form, field, group_label, row))
  end

  defp render_input(form, field, group_label, row = %{property: property})
       when property in ["color", "background-color", "border-color"] do
    color_input(form, field,
      value: value_or_default(row),
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "font-family"}) do
    select(
      form,
      field,
      [
        {gettext("Default"), "inherit"},
        {gettext("System"),
         ~s{-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Fira Sans", "Droid Sans", "Helvetica Neue", Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"}},
        {"Calibri", "Calibri, Carlito, PT Sans, Trebuchet MS, sans-serif"},
        {"Courier New", "Courier New, Courier, Liberation Mono, monospace"},
        {"Georgia", "Georgia, serif"},
        {"Helvetica/Arial", "Helvetica Neue, Helvetica, Arial, Nimbus Sans, sans-serif"},
        {"Times New Roman", "Times New Roman, Times, Liberation Serif, serif"},
        {"Trebuchet", "Trebuchet MS, Lucida Grande, Lucida Sans Unicode, sans-serif"},
        {"Ubuntu", "Ubuntu, PT Sans, Tahoma, sans-serif"},
        {"Verdana", "Verdana, sans-serif"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "font-weight"}) do
    select(
      form,
      field,
      [
        {gettext("normal"), "normal"},
        {gettext("bold"), "bold"},
        {gettext("light"), "300"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "font-style"}) do
    select(
      form,
      field,
      [
        {gettext("normal"), "normal"},
        {gettext("italic"), "italic"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "text-decoration"}) do
    select(
      form,
      field,
      [
        {gettext("none"), "none"},
        {gettext("underlined"), "underline"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "opacity"}) do
    select(
      form,
      field,
      [
        {gettext("invisible"), "0"},
        {gettext("very light"), "0.1"},
        {gettext("opacity-light"), "0.25"},
        {gettext("medium"), "0.50"},
        {gettext("almost opaque"), "0.75"},
        {gettext("opaque"), "1.0"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "border-style"}) do
    select(
      form,
      field,
      [
        {gettext("solid"), "solid"},
        {gettext("dotted"), "dotted"},
        {gettext("dashed"), "dashed"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "margin"}) do
    select(
      form,
      field,
      [
        {gettext("small"), "15px 0"},
        {gettext("medium"), "30px 0"},
        {gettext("large"), "45px 0"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "text-align"}) do
    select(
      form,
      field,
      [
        {gettext("flush left"), "left"},
        {gettext("flush right"), "right"},
        {gettext("centered"), "center"},
        {gettext("justified"), "justfy"}
      ],
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp render_input(form, field, group_label, row = %{property: "background-image"}) do
    text_input(form, field,
      type: "url",
      name: input_name(form, field, group_label, row),
      phx_debounce: 250,
      id: input_name(form, field, group_label, row),
      value: value_or_default(row)
    )
  end

  defp input_name(form, field, _group_label, %{selector: selector, property: property}) do
    "#{input_name(form, field)}[#{selector}__#{property}]"
  end

  defp value_or_default(row) do
    case row[:value] do
      nil -> row[:default]
      value -> value
    end
  end
end
