defmodule Keila.Mailings.Renderer.BodyRenderer.Markdown do
  @moduledoc """
  Renders the body for Markdown messages.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  alias Keila.Templates.HybridTemplate
  alias Keila.Templates.Html
  alias Keila.Mailings.Renderer.Input

  import Keila.Mailings.Renderer.LiquidRenderer

  @impl true
  def render(output, %Input{} = input, assigns) do
    main_content = input.text_body || ""
    styles = HybridTemplate.merge_styles(input.template)
    signature = get_signature(assigns)

    with {:ok, assigns} <- render_signature_to_assigns(assigns, signature),
         {:ok, assigns} <- render_main_content_to_assigns(assigns, main_content),
         {:ok, html_body} <- render_body(assigns) do
      html_body = apply_styles!(html_body, styles)
      text_body = build_text_body(assigns)

      %{output | text_body: text_body, html_body: html_body}
    else
      {:error, reason} ->
        %{output | text_body: reason, errors: [reason | output.errors]}
    end
  end

  defp render_signature_to_assigns(assigns, signature) do
    case render_liquid_and_markdown(signature, assigns) do
      {:ok, signature_text, signature_html} ->
        {:ok,
         assigns
         |> Map.put("signature_text", signature_text)
         |> Map.put("signature_html", signature_html)}

      {:error, reason} ->
        {:error, "Error processing signature: " <> reason}
    end
  end

  defp get_signature(assigns) do
    case assigns["signature"] do
      empty when empty in [nil, ""] -> HybridTemplate.signature()
      signature -> signature
    end
  end

  defp render_main_content_to_assigns(assigns, main_content) do
    case render_liquid_and_markdown(main_content, assigns) do
      {:ok, main_text, main_html} ->
        {:ok,
         assigns
         |> Map.put("main_text", main_text)
         |> Map.put("body_blocks", [%{"type" => "markdown", "data" => main_html}])
         |> Map.put("html_body_class", "keila--markdown-campaign")}

      {:error, reason} ->
        {:error, "Error processing main content: " <> reason}
    end
  end

  defp render_body(assigns) do
    template = HybridTemplate.html_template()
    opts = [file_system: HybridTemplate.file_system()]

    render_liquid(template, assigns, opts)
  end

  defp apply_styles!(html_body, styles) do
    html_body
    |> Html.parse_document!()
    |> Html.apply_email_markup()
    |> Html.apply_inline_styles(styles, ignore_inherit: true)
    |> Html.to_document()
  end

  defp build_text_body(assigns) do
    assigns["main_text"] <> "\n\n--  \n" <> assigns["signature_text"]
  end
end
