defmodule KeilaWeb.FormView do
  use KeilaWeb, :view
  alias Keila.Contacts.Contact

  import KeilaWeb.FormLayoutView, only: [build_styles: 1]

  @form_classes "contact-form container bg-white rounded py-4 md:py-8 flex flex-col gap-4"

  def render_form(form, changeset \\ Ecto.Changeset.change(%Contact{}), mode) do
    form_opts =
      []
      |> put_style_opts(form)
      |> maybe_put_csrf_opt(form, mode)

    form_for(
      changeset,
      Routes.form_url(KeilaWeb.Endpoint, :submit, form.id),
      form_opts,
      fn f ->
        [
          render_h1(form),
          render_intro(form),
          render_fields(form, f),
          render_captcha(form, mode, f),
          render_submit(form, f),
          render_fine_print(form)
        ]
      end
    )
  end

  defp put_style_opts(opts, form) do
    opts
    |> Keyword.put(:class, @form_classes)
    |> Keyword.put(:style, build_form_styles(form))
  end

  defp maybe_put_csrf_opt(opts, form, mode) do
    csrf_disabled? = mode == :embed or form.settings.csrf_disabled

    if csrf_disabled? do
      Keyword.put(opts, :csrf_token, false)
    else
      opts
    end
  end

  defp build_form_styles(form) do
    build_styles(%{
      "background-color" => form.settings.form_bg_color,
      "color" => form.settings.text_color
    })
  end

  defp render_h1(form) do
    content_tag(:h1, form.name, class: "text-4xl my-4")
  end

  defp render_intro(form) do
    if form.settings.intro_text do
      content_tag(:div, form.settings.intro_text, class: "text-xl")
    else
      []
    end
  end

  defp render_captcha(form, mode, f) do
    cond do
      form.settings.captcha_required and mode == :preview ->
        content_tag(:div, class: "p-5 h-15 shadow bg-gray-50 text-sm rounded w-1/3") do
          content_tag(:label) do
            [
              content_tag(:input, nil, type: "checkbox", class: "text-xl"),
              " ",
              gettext("I am human.")
            ]
          end
        end

      form.settings.captcha_required ->
        content_tag(:div, class: "flex flex-col") do
          with_validation(f, :captcha) do
            KeilaWeb.Captcha.captcha_tag()
          end
        end

      true ->
        []
    end
  end

  defp render_submit(form, _f) do
    content_tag(:div, class: "flex justify-start") do
      [
        content_tag(:button, form.settings.submit_label || gettext("Submit"),
          class: "button button--cta button--large",
          style:
            build_styles(%{
              "background-color" => form.settings.submit_bg_color,
              "color" => form.settings.submit_text_color
            })
        )
      ]
    end
  end

  defp render_fine_print(form) do
    if form.settings.fine_print do
      content_tag(
        :div,
        raw(Keila.Templates.Html.restrict(form.settings.fine_print, :limited)),
        class: "text-xs"
      )
    else
      []
    end
  end

  defp render_fields(form, f) do
    input_styles =
      build_styles(%{
        "background-color" => form.settings.input_bg_color,
        "color" => form.settings.input_text_color,
        "border-color" => form.settings.input_border_color
      })

    form.field_settings
    |> Enum.filter(& &1.cast)
    |> Enum.map(fn field_settings ->
      field = String.to_existing_atom(field_settings.field)

      content_tag(:div, class: "flex flex-col") do
        [
          label(f, field) do
            [
              field_settings.label || to_string(field),
              if(field_settings.required, do: "", else: [" ", gettext("(optional)")])
            ]
          end,
          with_validation(f, field) do
            if field in [:email] do
              email_input(f, field, placeholder: field_settings.placeholder, style: input_styles)
            else
              text_input(f, field, placeholder: field_settings.placeholder, style: input_styles)
            end
          end
        ]
      end
    end)
  end

  def render_form_success(form) do
    content_tag(:div, class: @form_classes, style: build_form_styles(form)) do
      [
        render_h1(form),
        render_success(form),
        render_fine_print(form)
      ]
    end
  end

  defp render_success(form) do
    content_tag(:div, form.settings.success_text || gettext("Thank you!"), class: "text-xl")
  end

  def render_unsubscribe_form(form) do
    form_styles = build_form_styles(form)

    content_tag(:div, class: @form_classes, style: form_styles) do
      gettext("You have been unsubscribed from this list.")
    end
  end
end
