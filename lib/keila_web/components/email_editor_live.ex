defmodule KeilaWeb.EmailEditorLiveComponent do
  @moduledoc """
  Editor for email content (campaigns and `Keila.Mailings.Email`).

  This component is designed to be used inside of a Phoenix form which
  must be provided as the `form` attribute. The form must be built from a
  changeset of a `Campaign` or `Email`.

  The parent must handle both input changes via `phx-change` and the
  `{:email_editor, id, params}` message via `handle_info/2` to update
  the form changeset.

  `_wysiwyg_dialogs.html` and `_preview_dialog.html` from
  `KeilaWeb.EmailEditorView` must be rendered once per page by the parent,
  outside its form.

  ## Assigns

  * `id`
  * `form` - the parent's `Phoenix.HTML.Form`
  * `type` - `:text`, `:markdown`, `:block`, `:mjml`, or `:html`
  * `project_id` - used to fetch the selected template
  * `to_input` - function `(content, recipient, assigns) -> Renderer.Input`
  * `config` - `Email.EditorConfig` (default: `%Email.EditorConfig{}`)
  * `preview_assigns` - assigns for the preview (default `%{}`)
  * `preview_contact` - contact for the preview (default: sample contact)
  """
  use KeilaWeb, :live_component

  alias Keila.Contacts.Contact
  alias Keila.Mailings.Email
  alias Keila.Mailings.Renderer
  alias Keila.Templates
  alias Keila.Templates.Css
  alias Keila.Templates.HybridTemplate
  alias Keila.Templates.Template

  @preview_contact %Contact{
    id: "c_id",
    first_name: "Jane",
    last_name: "Doe",
    email: "jane.doe@example.com",
    data: %{}
  }

  @impl true
  def mount(socket) do
    {:ok, assign(socket, template_id: nil, template: nil, styles_key: nil, styles: "")}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:config, fn -> %Email.EditorConfig{} end)
      |> assign_new(:preview_assigns, fn -> %{} end)
      |> assign_new(:preview_contact, fn -> @preview_contact end)
      |> fetch_template()
      |> put_preview()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.EmailEditorView, "email_editor.html", assigns)
  end

  @impl true
  def handle_event("merge_mjml_template", _params, socket) do
    content = current_content(socket)
    template = socket.assigns.template
    template_mjml = (template && template.mjml_body) || ""

    mjml =
      Templates.merge_content_slots(template_mjml, content.mjml_content,
        mode: :mjml,
        pretty: true
      )

    send_change(socket, %{"mjml_body" => mjml, "mjml_content" => %{}})
  end

  def handle_event("merge_text_template", _params, socket) do
    content = current_content(socket)
    template = socket.assigns.template
    template_text = (template && template.text_body) || ""
    text = Templates.merge_content_slots(template_text, content.text_content, mode: :text)

    send_change(socket, %{"text_body" => text, "text_content" => %{}})
  end

  def handle_event("merge_html_template", _params, socket) do
    content = current_content(socket)
    template = socket.assigns.template
    template_html = (template && template.html_body) || ""

    html =
      Templates.merge_content_slots(template_html, content.html_content,
        mode: :html,
        pretty: true
      )

    send_change(socket, %{"html_body" => html, "html_content" => %{}})
  end

  defp send_change(socket, params) do
    send(self(), {:email_editor, socket.assigns.id, params})
    {:noreply, socket}
  end

  defp current_content(socket) do
    socket.assigns.form.source
    |> Ecto.Changeset.apply_changes()
    |> put_template(socket.assigns.template)
  end

  defp fetch_template(socket) do
    template_id = Ecto.Changeset.get_field(socket.assigns.form.source, :template_id)

    if socket.assigns.template_id == template_id do
      socket
    else
      template =
        template_id && Templates.get_project_template(socket.assigns.project_id, template_id)

      assign(socket, template_id: template_id, template: template)
    end
  end

  defp put_preview(socket) do
    %{form: form, type: type, template: template} = socket.assigns
    content = form.source |> Ecto.Changeset.apply_changes() |> put_template(template)

    socket
    |> assign(:preview, render_preview(socket.assigns, content))
    |> assign(:content_slots, content_slots(content, template, type))
    |> assign(:json_body, encode_json_body(content))
    |> maybe_put_styles(template, type)
  end

  defp put_template(%{template: _} = content, template),
    do: %{content | template: template}

  defp put_template(content, _template), do: content

  defp render_preview(assigns, content) do
    input = assigns.to_input.(content, assigns.preview_contact, assigns.preview_assigns)
    output = Renderer.render_preview(input)

    output.html_body || KeilaWeb.CampaignView.plain_text_preview(output.text_body)
  end

  defp content_slots(content, template, type) do
    with {template_body, mode} when template_body not in [nil, ""] <- template_body(template),
         true <- mode == type,
         body when body in [nil, ""] <- body(content, mode) do
      Templates.get_content_slots(template_body, mode: mode)
    else
      _ -> []
    end
  end

  defp template_body(%Template{type: :mjml, mjml_body: body}), do: {body, :mjml}
  defp template_body(%Template{type: :text, text_body: body}), do: {body, :text}
  defp template_body(%Template{type: :html, html_body: body}), do: {body, :html}
  defp template_body(_), do: nil

  defp body(%{mjml_body: body}, :mjml), do: body
  defp body(%{text_body: body}, :text), do: body
  defp body(%{html_body: body}, :html), do: body
  defp body(_, _), do: nil

  defp encode_json_body(content) do
    case Map.get(content, :json_body) do
      nil -> "{}"
      json_body -> Jason.encode!(json_body)
    end
  end

  defp maybe_put_styles(socket, template, type) do
    key = {template && template.id, template && template.updated_at, type}

    if socket.assigns.styles_key == key do
      socket
    else
      socket
      |> assign(:styles_key, key)
      |> assign(:styles, editor_styles(template, type, socket.assigns.id))
    end
  end

  defp editor_styles(template, type, id) do
    template_styles =
      if template && template.styles do
        Css.parse!(template.styles)
      else
        []
      end

    HybridTemplate.styles()
    |> Css.merge(template_styles)
    |> Enum.map(fn {selector, styles} ->
      selector =
        selector
        |> String.split(",")
        |> Enum.map(&transform_style_selector(&1, type, id))
        |> Enum.join(",")

      {selector, styles}
    end)
    |> Css.encode()
  end

  defp transform_style_selector(selector, :markdown, id) do
    editor_selector = "##{id}-wysiwyg .editor"
    content_selector = editor_selector <> " .ProseMirror"

    case selector do
      ".email-bg" -> editor_selector
      "#content" <> selector -> content_selector <> selector
      ".block--button .button-td" -> editor_selector <> " h4 a"
      ".block--button .button-a" -> editor_selector <> " h4 a"
      selector -> editor_selector <> " " <> selector
    end
  end

  defp transform_style_selector(selector, :block, id) do
    editor_selector = "##{id}-block .editor"
    content_selector = editor_selector <> " .codex-editor__redactor"

    case selector do
      ".email-bg" ->
        editor_selector

      "#content" <> selector ->
        content_selector <> selector

      ".block--button .button-td" ->
        editor_selector <> " .ce-block--type-button .button-contenteditable"

      ".block--button .button-a" ->
        editor_selector <> " .ce-block--type-button .button-contenteditable"

      selector ->
        editor_selector <> " " <> selector
    end
  end

  defp transform_style_selector(selector, _other, _id), do: selector
end
