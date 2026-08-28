defmodule Keila.Mailings.Renderer.BodyRenderer.Html do
  @moduledoc """
  Renders the body for HTML messages.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  use KeilaWeb.Gettext
  alias Keila.Mailings.Renderer
  alias Keila.Mailings.Renderer.Input
  import Keila.Mailings.Renderer.LiquidRenderer

  @impl true
  def render(output, %Input{} = input, assigns) do
    with {:ok, liquid_template} <- liquid_template(input),
         {:ok, html_body} <- render_liquid(liquid_template, assigns) do
      %{output | html_body: html_body, text_body: Renderer.html_to_text(html_body)}
    else
      {:error, reason} ->
        %{output | text_body: reason, errors: [reason | output.errors]}
    end
  end

  defp liquid_template(input) do
    hash = input_hash(input)

    Keila.Mailings.Renderer.LiquidCache.get(hash, fn ->
      input
      |> merge_html()
      |> parse_liquid()
    end)
  end

  defp input_hash(%Input{html_body: html_body, template: template, html_content: html_content}) do
    :crypto.hash(:sha256, :erlang.term_to_binary({html_body, template, html_content}))
  end

  defp merge_html(%Input{html_body: html_body, template: template, html_content: html_content}) do
    body =
      case {html_body, template} do
        {html, _} when is_binary(html) and html != "" -> html
        {_, %{html_body: html}} when is_binary(html) -> html
        _ -> ""
      end

    Keila.Templates.merge_content_slots(body, html_content || %{}, mode: :html)
  end
end
