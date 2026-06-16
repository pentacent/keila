defmodule Keila.Mailings.Renderer.BodyRenderer.Block do
  @moduledoc """
  Renders the body for block messages using the HybridTemplate.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  alias Keila.Mailings.Renderer.Input
  alias Keila.Templates.{Css, Html, HybridTemplate}
  import Keila.Mailings.Renderer.LiquidRenderer

  @impl true
  def render(output, %Input{} = input, assigns) do
    {output, assigns} = put_signature(output, assigns)
    {output, body_blocks} = get_body_blocks(output, input.json_body, assigns)

    styles = HybridTemplate.merge_styles(input.template)

    embedded_css =
      styles
      |> Enum.filter(fn {selector, _} -> selector in HybridTemplate.embedded_styles() end)
      |> Css.encode(styles)

    assigns =
      assigns
      |> Map.put("body_blocks", body_blocks)
      |> Map.put("embedded_css", embedded_css)
      |> Map.put("html_body_class", "keila--block-campaign")

    with {:ok, html_body} <-
           render_liquid(HybridTemplate.html_template(), assigns,
             file_system: HybridTemplate.file_system()
           ) do
      html_body =
        html_body
        |> Html.parse_document!()
        |> Html.apply_inline_styles(styles, ignore_inherit: true)
        |> Html.to_document()

      %{output | html_body: html_body}
    else
      {:error, error} ->
        %{output | text_body: error, errors: [error | output.errors]}
    end
  end

  defp put_signature(output, assigns) do
    signature = assigns["signature"] || HybridTemplate.signature()

    with {:ok, signature_text} <- render_liquid(signature, assigns),
         {:ok, signature_html, _} <- Earmark.as_html(signature_text) do
      assigns =
        assigns
        |> Map.put("signature_text", signature_text)
        |> Map.put("signature_html", signature_html)

      {output, assigns}
    else
      error ->
        error_message =
          case error do
            {:error, reason} when is_binary(reason) -> "Parsing error:\n" <> reason
            _other -> "Unexpected parsing error"
          end

        assigns =
          assigns
          |> Map.put("signature_text", error_message)
          |> Map.put("signature_html", error_message)

        {%{output | errors: [error_message | output.errors]}, assigns}
    end
  end

  defp get_body_blocks(output, json_body, assigns) do
    (json_body || %{})
    |> Map.get("blocks", [])
    |> apply_liquid_to_blocks(assigns)
    |> case do
      {:ok, blocks} ->
        {output, blocks}

      {:error, blocks} ->
        {%{output | errors: ["Rendering error" | output.errors]}, blocks}
    end
  end

  defp apply_liquid_to_blocks(blocks, assigns) do
    blocks
    |> Enum.reverse()
    |> Enum.reduce({:ok, []}, fn block, {status, blocks} ->
      {rendered_status, rendered_block} = apply_liquid(block, assigns)
      updated_status = if status == :ok && rendered_status == :ok, do: :ok, else: :error
      {updated_status, [rendered_block | blocks]}
    end)
  end

  defp apply_liquid(map, assigns) when is_map(map) do
    {rendered_map, statuses} =
      Enum.reduce(map, {%{}, []}, fn {key, value}, {acc, statuses} ->
        {status, rendered_value} = apply_liquid(value, assigns)
        {Map.put(acc, key, rendered_value), [status | statuses]}
      end)

    status = if Enum.all?(statuses, &(&1 == :ok)), do: :ok, else: :error
    {status, rendered_map}
  end

  defp apply_liquid(list, assigns) when is_list(list) do
    {reversed_rendered_list, statuses} =
      Enum.reduce(list, {[], []}, fn value, {acc, statuses} ->
        {status, rendered_value} = apply_liquid(value, assigns)
        {[rendered_value | acc], [status | statuses]}
      end)

    status = if Enum.all?(statuses, &(&1 == :ok)), do: :ok, else: :error
    {status, Enum.reverse(reversed_rendered_list)}
  end

  defp apply_liquid(string, assigns) when is_binary(string) do
    render_liquid(string, assigns)
  end

  defp apply_liquid(other, _assigns), do: {:ok, other}
end
