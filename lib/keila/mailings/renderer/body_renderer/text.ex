defmodule Keila.Mailings.Renderer.BodyRenderer.Text do
  @moduledoc """
  Renders the body for plain-text messages.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  alias Keila.Mailings.Renderer.Input
  alias Keila.Templates.HybridTemplate
  import Keila.Mailings.Renderer.LiquidRenderer

  @impl true
  def render(output, %Input{} = input, assigns) do
    case render_liquid(body(input, assigns), assigns) do
      {:ok, text_body} ->
        %{output | text_body: text_body}

      {:error, error} ->
        %{output | text_body: error, errors: [error | output.errors]}
    end
  end

  # Without a template, append the signature directly to the body.
  # This is the legacy behavior from before there were text templates.
  # and might be deprecated in the future
  defp body(%Input{template: nil} = input, assigns) do
    signature = assigns["signature"] || HybridTemplate.text_signature()

    if signature == "" do
      input.text_body || ""
    else
      (input.text_body || "") <> "\n\n--  \n" <> signature
    end
  end

  # With a template, merge the body into the template's text content slots.
  defp body(%Input{} = input, _assigns) do
    text_body =
      case {input.text_body, input.template} do
        {body, _} when is_binary(body) and body != "" -> body
        {_, %{text_body: body}} when is_binary(body) -> body
        _ -> ""
      end

    Keila.Templates.merge_content_slots(text_body, input.text_content || %{}, mode: :text)
  end
end
