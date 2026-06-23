defmodule Keila.Mailings.Renderer.BodyRenderer.Html do
  @moduledoc """
  Renders the body for HTML messages.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  use KeilaWeb.Gettext
  alias Keila.Mailings.Renderer
  alias Keila.Mailings.Renderer.Input

  @impl true
  def render(output, %Input{} = input, assigns) do
    case render_liquid(merged_html(input), assigns) do
      {:ok, rendered_html} ->
        %{
          output
          | html_body: rendered_html,
            text_body: Renderer.html_to_text(rendered_html)
        }

      {:error, reason} ->
        %{output | text_body: reason, errors: [reason | output.errors]}
    end
  end

  defp merged_html(%Input{html_body: html_body, template: template, html_content: html_content}) do
    body =
      case {html_body, template} do
        {html, _} when is_binary(html) and html != "" -> html
        {_, %{html_body: html}} when is_binary(html) -> html
        _ -> ""
      end

    Keila.Templates.merge_content_slots(body, html_content || %{}, mode: :html)
  end

  defp render_liquid(input, assigns) do
    case Keila.Mailings.Renderer.LiquidRenderer.render_liquid(input, assigns) do
      {:ok, output} ->
        {:ok, output}

      {:error, reason} ->
        {:error, gettext("Error compiling Liquid: %{reason}", reason: reason)}
    end
  end
end
