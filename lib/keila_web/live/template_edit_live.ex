defmodule KeilaWeb.TemplateEditLive do
  use KeilaWeb, :live_view
  alias Keila.Templates.{Template, StyleTemplate, HybridTemplate}
  alias Keila.Mailings.Renderer

  @external_resource "priv/email_templates/default-markdown-content.md"
  @default_markdown_body File.read!("priv/email_templates/default-markdown-content.md")

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])

    template = session["template"]
    styles = if template.type == :hybrid, do: Keila.Templates.Css.parse!(template.styles || "")

    style_template =
      if template.type == :hybrid,
        do:
          HybridTemplate.style_template()
          |> StyleTemplate.apply_values_from_css(styles)

    socket =
      socket
      |> assign(:template, template)
      |> assign(:changeset, Ecto.Changeset.change(template))
      |> assign(:current_project, session["current_project"])
      |> assign(:style_template, style_template)
      |> put_template_preview()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.TemplateView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", %{"template" => params}, socket) do
    template = socket.assigns.template

    style_template =
      if template.type == :hybrid,
        do:
          StyleTemplate.apply_values_from_params(socket.assigns.style_template, params["styles"])

    changeset =
      Template.update_changeset(
        socket.assigns.template,
        Map.delete(params, "styles")
      )

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:style_template, style_template)
      |> put_template_preview()

    {:noreply, socket}
  end

  defp put_template_preview(socket) do
    {:ok, template} = Ecto.Changeset.apply_action(socket.assigns.changeset, :update)
    assign(socket, :preview, render_preview(template, socket.assigns))
  end

  defp render_preview(%Template{type: :hybrid} = template, assigns) do
    template = %{template | styles: StyleTemplate.to_css(assigns.style_template)}

    %Renderer.Input{
      type: :markdown,
      subject: "",
      text_body: @default_markdown_body,
      template: template,
      assigns: %{"campaign" => %{"subject" => template.name}}
    }
    |> Renderer.render_preview()
    |> preview_html()
  end

  defp render_preview(%Template{type: type} = template, _assigns)
       when type in [:mjml, :html, :text] do
    %Renderer.Input{
      type: type,
      subject: "",
      text_body: template.text_body,
      template: template,
      assigns: %{"campaign" => %{"subject" => template.name}}
    }
    |> Renderer.render_preview()
    |> preview_html()
  end

  defp preview_html(%Keila.Mailings.Renderer.Output{} = output) do
    output.html_body || KeilaWeb.CampaignView.plain_text_preview(output.text_body)
  end
end
