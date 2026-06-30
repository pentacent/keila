defmodule Keila.Mailings.Renderer.BodyRenderer.Mjml do
  @moduledoc """
  Renderer for MJML emails.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  use KeilaWeb.Gettext
  alias Keila.Mailings.Renderer
  alias Keila.Mailings.Renderer.Input

  @impl true
  def render(output, %Input{} = input, assigns) do
    mjml =
      input
      |> merge_mjml()
      |> remove_code_blocks()

    with {:ok, mjml} <- render_liquid(mjml, assigns),
         {:ok, html_body} <- render_mjml(mjml) do
      %{
        output
        | html_body: html_body,
          text_body: Renderer.html_to_text(html_body)
      }
    else
      {:error, reason} ->
        %{output | text_body: reason, errors: [reason | output.errors]}
    end
  end

  defp merge_mjml(%Input{mjml_body: mjml_body, template: template, mjml_content: mjml_content}) do
    body =
      case {mjml_body, template} do
        {mjml, _} when is_binary(mjml) and mjml != "" -> mjml
        {_, %{mjml_body: mjml}} when is_binary(mjml) -> mjml
        _ -> ""
      end

    Keila.Templates.merge_content_slots(body, mjml_content || %{}, mode: :mjml)
  end

  # Strips the `<keila-code>` wrapper tags the WYSIWYG editor uses to handle Liquid
  # control flow tags.
  defp remove_code_blocks(mjml) do
    String.replace(mjml, ~r{</?keila-code\s*/?>}, "")
  end

  defp render_mjml(mjml) do
    case Mjml.to_html(normalize_newlines(mjml)) do
      {:ok, html} ->
        {:ok, html}

      {:error, reason} ->
        {:error, gettext("Error compiling MJML: %{reason}", reason: reason)}
    end
  end

  # FIXME: There is currently a bug in MRML that requires this workaround.
  # This should be removed once the bug has been fixed.
  # https://github.com/jdrouet/mrml/issues/654
  defp normalize_newlines(mjml) do
    String.replace(mjml, ~r/\r\n?/, "\n")
  end

  defp render_liquid(mjml, assigns) do
    case Keila.Mailings.Renderer.LiquidRenderer.render_liquid(mjml, assigns) do
      {:ok, rendered_mjml} ->
        {:ok, rendered_mjml}

      {:error, reason} ->
        {:error, gettext("Error compiling Liquid: %{reason}", reason: reason)}
    end
  end
end
