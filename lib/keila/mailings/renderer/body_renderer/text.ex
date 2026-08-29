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
    with {:ok, liquid_template} <- liquid_template(input, assigns),
         {:ok, text_body} <- render_liquid(liquid_template, assigns) do
      %{output | text_body: text_body}
    else
      {:error, error} ->
        %{output | text_body: error, errors: [error | output.errors]}
    end
  end

  defp liquid_template(input, assigns) do
    hash = input_hash(input, assigns)

    Keila.Mailings.Renderer.LiquidCache.get(hash, fn ->
      input
      |> merge_text(assigns)
      |> parse_liquid()
    end)
  end

  defp input_hash(
         %Input{text_body: text_body, text_content: text_content, template: template},
         assigns
       ) do
    signature = assigns["signature"]
    template_fields = if template, do: Map.take(template, [:id, :updated_at, :name, :text_body])

    :crypto.hash(
      :sha256,
      :erlang.term_to_binary({text_body, text_content, signature, template_fields})
    )
  end

  # Without a template, append the signature directly to the body.
  # This is the legacy behavior from before there were text templates.
  # and might be deprecated in the future
  defp merge_text(%Input{template: nil} = input, assigns) do
    signature = assigns["signature"] || HybridTemplate.text_signature()

    if signature == "" do
      input.text_body || ""
    else
      (input.text_body || "") <> "\n\n--  \n" <> signature
    end
  end

  # With a template, merge the body into the template's text content slots.
  defp merge_text(%Input{} = input, _assigns) do
    text_body =
      case {input.text_body, input.template} do
        {body, _} when is_binary(body) and body != "" -> body
        {_, %{text_body: body}} when is_binary(body) -> body
        _ -> ""
      end

    Keila.Templates.merge_content_slots(text_body, input.text_content || %{}, mode: :text)
  end
end
