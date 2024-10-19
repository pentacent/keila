defmodule KeilaWeb.CampaignEditLive do
  use KeilaWeb, :live_view
  alias Keila.Mailings

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])

    project = session["current_project"]
    senders = session["senders"]
    segments = session["segments"]
    templates = session["templates"] || []
    campaign = session["campaign"]
    changeset = Ecto.Changeset.change(campaign, %{})

    socket =
      socket
      |> assign(:current_project, project)
      |> assign(:campaign, campaign)
      |> assign(:senders, senders)
      |> assign(:segments, segments)
      |> assign(:templates, templates)
      |> assign(:changeset, changeset)
      |> assign(:settings_changeset, changeset)
      |> put_recipient_count()
      |> put_campaign_preview()

    {:ok, socket}
  end

  defp put_campaign_preview(socket) do
    campaign = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    template = Enum.find(socket.assigns.templates, &(&1.id == campaign.template_id))

    # TODO
    sender =
      Enum.find(socket.assigns.senders, &(&1.id == campaign.sender_id)) ||
        %Mailings.Sender{from_email: "foo@example.com"}

    campaign = %Mailings.Campaign{campaign | sender: sender, template: template}
    email = Mailings.Builder.build(campaign, %{})
    preview = email.html_body || KeilaWeb.CampaignView.plain_text_preview(email.text_body)

    json_body = if campaign.json_body, do: Jason.encode!(campaign.json_body), else: "{}"

    socket
    |> maybe_put_styles(template)
    |> assign(:preview, preview)
    |> assign(:json_body, json_body)
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.CampaignView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("update", params, socket) do
    changeset = merged_changeset(socket, params["campaign"])

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:settings_changeset, changeset)
      |> put_recipient_count()
      |> put_campaign_preview()

    {:noreply, socket}
  end

  def handle_event("update-settings", params, socket) do
    changeset = merged_changeset(socket, params["campaign"])

    if changeset.valid? do
      socket =
        socket
        |> assign(:settings_changeset, changeset)
        |> assign(:changeset, changeset)
        |> put_recipient_count()
        |> put_campaign_preview()
        |> push_event("settings_validated", %{valid: true})

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:settings_changeset, %{changeset | action: :update})
        |> push_event("settings_validated", %{valid: false})

      {:noreply, socket}
    end
  end

  def handle_event("save", params, socket) do
    changeset = merged_changeset(socket, params["campaign"])
    merged_params = changeset.params || %{}

    Mailings.update_campaign(socket.assigns.campaign.id, merged_params, false)
    |> case do
      {:ok, campaign} ->
        {:noreply,
         redirect(socket, to: Routes.campaign_path(socket, :index, campaign.project_id))}

      {:error, changeset} ->
        {:noreply, put_changesets(socket, changeset)}
    end
  end

  def handle_event("send", _, socket) do
    params = socket.assigns.changeset.params || %{}

    Mailings.update_campaign(socket.assigns.campaign.id, params, true)
    |> case do
      {:ok, campaign} ->
        Mailings.deliver_campaign_async(campaign.id)

        {:noreply,
         redirect(socket,
           to: Routes.campaign_path(socket, :stats, campaign.project_id, campaign.id)
         )}

      {:error, changeset} ->
        {:noreply, put_changesets(socket, changeset)}
    end
  end

  def handle_event("schedule", params, socket) do
    scheduled_for =
      with schedule_params when is_map(schedule_params) <- params["schedule"],
           {:ok, date} <- Date.from_iso8601(schedule_params["date"]),
           {:ok, time} <- Time.from_iso8601(schedule_params["time"] <> ":00"),
           {:ok, datetime} <- DateTime.new(date, time, schedule_params["timezone"]),
           {:ok, scheduled_for} <- DateTime.shift_zone(datetime, "Etc/UTC") do
        scheduled_for
      else
        _ -> nil
      end

    params = socket.assigns.changeset.params || %{}

    with {:ok, campaign} <-
           Mailings.update_campaign(socket.assigns.campaign.id, params, true),
         {:ok, campaign} <-
           Mailings.schedule_campaign(campaign.id, %{scheduled_for: scheduled_for}) do
      {:noreply, redirect(socket, to: Routes.campaign_path(socket, :index, campaign.project_id))}
    else
      {:error, changeset} ->
        {:noreply, put_changesets(socket, changeset) |> put_campaign_preview()}
    end
  end

  def handle_event("unschedule", _params, socket) do
    handle_event("schedule", %{}, socket)
  end

  defp merged_changeset(socket, params) do
    params = maybe_parse_json_body(params)

    merged_params =
      Mailings.Campaign.preview_changeset(socket.assigns.changeset, params)
      |> Map.fetch!(:params)
      |> then(fn params -> params || %{} end)

    Mailings.Campaign.preview_changeset(socket.assigns.campaign, merged_params)
  end

  defp maybe_parse_json_body(%{"json_body" => raw_json_body} = params)
       when is_binary(raw_json_body) do
    case Jason.decode(raw_json_body) do
      {:ok, json_body} -> Map.replace!(params, "json_body", json_body)
      _other -> params
    end
  end

  defp maybe_parse_json_body(params), do: params

  defp maybe_put_styles(socket, template) do
    if (is_nil(template) && is_nil(socket.assigns[:styles])) ||
         (not is_nil(template) && socket.assigns[:current_template_id] != template.id) do
      template_styles =
        if template && template.styles do
          Keila.Templates.Css.parse!(template.styles)
        else
          []
        end

      default_styles = Keila.Templates.HybridTemplate.styles()

      campaign_type = socket.assigns.campaign.settings.type

      styles =
        Keila.Templates.Css.merge(default_styles, template_styles)
        |> Enum.map(fn {selector, styles} ->
          selector =
            selector
            |> String.split(",")
            |> Enum.map(&transform_style_selector(&1, campaign_type))
            |> Enum.join(",")

          {selector, styles}
        end)
        |> Keila.Templates.Css.encode()

      socket
      |> assign(:current_template_id, if(template, do: template.id))
      |> assign(:styles, styles)
    else
      if is_nil(socket.assigns[:styles]) do
        assign(socket, :styles, "")
      else
        socket
      end
    end
  end

  defp transform_style_selector(selector, :text), do: selector

  defp transform_style_selector(selector, :mjml), do: selector

  @markdown_editor_selector "#wysiwyg .editor"
  @markdown_editor_content_selector "#wysiwyg .editor .ProseMirror"
  defp transform_style_selector(selector, :markdown) do
    case selector do
      ".email-bg" -> @markdown_editor_selector
      "#content" <> selector -> @markdown_editor_content_selector <> selector
      ".block--button .button-td" -> @markdown_editor_selector <> " h4 a"
      ".block--button .button-a" -> @markdown_editor_selector <> " h4 a"
      selector -> @markdown_editor_selector <> " " <> selector
    end
  end

  @block_editor_selector "#block-container .editor"
  @block_editor_content_selector "#block-container .editor .codex-editor__redactor"
  defp transform_style_selector(selector, :block) do
    case selector do
      ".email-bg" ->
        @block_editor_selector

      "#content" <> selector ->
        @block_editor_content_selector <> selector

      ".block--button .button-td" ->
        @block_editor_selector <> " .ce-block--type-button .button-contenteditable"

      ".block--button .button-a" ->
        @block_editor_selector <> " .ce-block--type-button .button-contenteditable"

      selector ->
        @block_editor_selector <> " " <> selector
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

  def put_changesets(socket, changeset) do
    socket
    |> assign(:changeset, changeset)
    |> assign(:settings_changeset, changeset)
  end
end
