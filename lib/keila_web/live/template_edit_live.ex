defmodule KeilaWeb.TemplateEditLive do
  use KeilaWeb, :live_view
  alias Keila.Templates.{Template, StyleTemplate, DefaultTemplate}

  @default_text_body File.read!("priv/email_templates/default-markdown-content.md")

  @impl true
  def mount(_params, session, socket) do
    styles = Keila.Templates.Css.parse!(session["template"].styles || "")

    style_template =
      DefaultTemplate.style_template()
      |> StyleTemplate.apply_values_from_css(styles)

    socket =
      socket
      |> assign(:template, session["template"])
      |> assign(:changeset, Ecto.Changeset.change(session["template"]))
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
  def handle_event("form_updated", params, socket) do
    style_template =
      StyleTemplate.apply_values_from_params(
        socket.assigns.style_template,
        params["template"]["styles"]
      )

    changeset =
      Template.update_changeset(
        socket.assigns.template,
        Map.delete(params["template"], "styles")
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

    css_preview =
      socket.assigns.style_template
      |> StyleTemplate.to_css()

    template = %{template | styles: css_preview}

    campaign = %Keila.Mailings.Campaign{
      id: 0,
      subject: "",
      project_id: socket.assigns.current_project.id,
      text_body: @default_text_body,
      settings: %Keila.Mailings.Campaign.Settings{type: :markdown},
      template: template,
      sender: %Keila.Mailings.Sender{from_name: "Example", from_email: "keila@example.com"}
    }

    preview_email = Keila.Mailings.Builder.build(campaign, %{})

    assign(socket, :preview, preview_email.html_body)
  end
end
