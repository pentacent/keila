defmodule KeilaWeb.TemplateEditLive do
  use KeilaWeb, :live_view
  alias Keila.Templates.{Template, StyleTemplate, HybridTemplate}

  @default_text_body File.read!("priv/email_templates/default-markdown-content.md")

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
    assign(socket, :preview, build_preview(template, socket.assigns))
  end

  defp build_preview(%Template{type: :hybrid} = template, assigns) do
    css_preview =
      assigns.style_template
      |> StyleTemplate.to_css()

    template = %{template | styles: css_preview}

    campaign = %Keila.Mailings.Campaign{
      id: nil,
      subject: "",
      project_id: assigns.current_project.id,
      text_body: @default_text_body,
      settings: %Keila.Mailings.Campaign.Settings{type: :markdown},
      template: template
    }

    email = Keila.Mailings.Builder.build_preview(campaign)
    email.html_body || KeilaWeb.CampaignView.plain_text_preview(email.text_body)
  end

  defp build_preview(%Template{type: type} = template, assigns)
       when type in [:mjml, :html, :text] do
    campaign = %Keila.Mailings.Campaign{
      id: nil,
      subject: "",
      project_id: assigns.current_project.id,
      settings: %Keila.Mailings.Campaign.Settings{type: type},
      template: template,
      text_body: template.text_body
    }

    email = Keila.Mailings.Builder.build_preview(campaign)
    email.html_body || KeilaWeb.CampaignView.plain_text_preview(email.text_body)
  end
end
