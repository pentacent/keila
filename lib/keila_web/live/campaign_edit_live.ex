defmodule KeilaWeb.CampaignEditLive do
  use KeilaWeb, :live_view
  alias Keila.Mailings

  @impl true
  def mount(_params, session, socket) do
    project = session["current_project"]
    senders = session["senders"]
    segments = session["segments"]
    templates = session["templates"] || []
    campaign = session["campaign"]
    error_changeset = session["changeset"]

    changeset =
      case session["params"] do
        nil ->
          Ecto.Changeset.change(campaign)

        params ->
          changeset = Mailings.Campaign.update_changeset(campaign, params)

          case Ecto.Changeset.apply_action(changeset, :update) do
            {:error, changeset} -> changeset
            _ -> changeset
          end
      end

    socket =
      socket
      |> assign(:current_project, project)
      |> assign(:campaign, campaign)
      |> assign(:senders, senders)
      |> assign(:segments, segments)
      |> assign(:templates, templates)
      |> assign(:changeset, changeset)
      |> assign(:error_changeset, error_changeset)
      |> put_recipient_count()
      |> put_default_assigns()

    {:ok, socket}
  end

  defp put_default_assigns(socket) do
    case Ecto.Changeset.apply_action(socket.assigns.changeset, :update) do
      {:ok, campaign} ->
        template = Enum.find(socket.assigns.templates, &(&1.id == campaign.template_id))

        # TODO
        sender =
          Enum.find(socket.assigns.senders, &(&1.id == campaign.sender_id)) ||
            %Mailings.Sender{from_email: "foo@example.com"}

        campaign = %Mailings.Campaign{campaign | sender: sender, template: template}
        email = Mailings.Builder.build(campaign, %{})

        preview =
          case campaign.settings.type do
            :markdown -> email.html_body
            :text -> KeilaWeb.CampaignView.plain_text_preview(email.text_body)
          end

        socket
        |> maybe_put_styles(template)
        |> assign(:preview, preview)

      _ ->
        assign(socket, :preview, "")
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.CampaignView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", params, socket) do
    changeset =
      Keila.Mailings.Campaign.preview_changeset(socket.assigns.campaign, params["campaign"])

    socket =
      socket
      |> assign(:changeset, changeset)
      |> put_recipient_count()
      |> put_default_assigns()

    {:noreply, socket}
  end

  defp maybe_put_styles(socket, template) do
    if (is_nil(template) && is_nil(socket.assigns[:styles])) ||
         (not is_nil(template) && socket.assigns[:current_template_id] != template.id) do
      template_styles =
        if template && template.styles do
          Keila.Templates.Css.parse!(template.styles)
        else
          []
        end

      default_styles = Keila.Templates.DefaultTemplate.styles()

      styles =
        Keila.Templates.Css.merge(default_styles, template_styles)
        |> Enum.map(fn {selector, styles} ->
          cond do
            String.starts_with?(selector, "body") ->
              {String.replace(selector, "body", "#wysiwyg .editor"), styles}

            String.starts_with?(selector, "#content") ->
              {String.replace(selector, "#content", "#wysiwyg .editor .ProseMirror"), styles}

            true ->
              {"#wysiwyg .ProseMirror " <> selector, styles}
          end
        end)
        |> Keila.Templates.Css.encode()

      socket
      |> assign(:current_template_id, if(template, do: template.id))
      |> assign(:styles, styles)
    else
      socket
    end
  end

  defp put_recipient_count(socket) do
    segment_id = Ecto.Changeset.get_field(socket.assigns.changeset, :segment_id)

    if !Map.has_key?(socket.assigns, :segment_id) ||
         Map.get(socket.assigns, :segment_id) != segment_id do
      segment_filter =
        case segment_id do
          nil ->
            %{}

          segment_id ->
            segments = socket.assigns.segments

            Enum.find_value(segments, fn segment ->
              if segment.id == segment_id, do: segment.filter
            end)
        end

      filter = %{"$and" => [segment_filter, %{"status" => "active"}]}

      recipient_count =
        Keila.Contacts.get_project_contacts_count(socket.assigns.current_project.id,
          filter: filter
        )

      socket
      |> assign(:segment_id, segment_id)
      |> assign(:recipient_count, recipient_count)
    else
      socket
    end
  end
end
