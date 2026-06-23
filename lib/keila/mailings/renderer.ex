defmodule Keila.Mailings.Renderer do
  @moduledoc """
  Module for rendering message content with Liquid and template logic.

  Message bodies are rendered with a `BodyRenderer` module specific to the input `type`.
  """

  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias KeilaWeb.Router.Helpers, as: Routes
  alias Keila.Templates.Template
  alias __MODULE__.Input
  alias __MODULE__.Output
  alias __MODULE__.BodyRenderer
  import __MODULE__.LiquidRenderer

  @doc """
  Renders an `Input` into an `Output` (subject + bodies).

  If an error occurred during rendering, the output stuct sets `valid?` to `false`
  and adds error strings to `errors`. Invalid outputs must not be sent out as emails.

  For more details on the `Input` and `Output` data structures refer to the
  respective module documentation.
  """
  @spec render(Input.t()) :: Output.t()
  def render(%Input{} = input) do
    assigns = build_assigns(input)

    %Output{}
    |> render_subject(input, assigns)
    |> render_body(input, assigns)
    |> then(fn output ->
      valid? = output.valid? and Enum.empty?(output.errors)
      errors = Enum.reverse(output.errors)
      %{output | valid?: valid?, errors: errors}
    end)
  rescue
    e ->
      %Output{valid?: false, errors: ["Unexpected render error: #{Exception.message(e)}"]}
  end

  defp build_assigns(input) do
    input.assigns
    |> put_template_assigns(input.template)
    |> Map.put_new("contact", contact_assigns(input))
    |> Map.put_new("assets_url", Routes.static_url(KeilaWeb.Endpoint, "/"))
    |> process_assigns()
  end

  defp put_template_assigns(assigns, %Template{assigns: template_assigns = %{}}),
    do: Map.merge(template_assigns, assigns)

  defp put_template_assigns(assigns, _), do: assigns

  defp contact_assigns(%Input{contact: contact = %Contact{}}) do
    contact
    |> process_assigns()
    |> Map.put("display_name", Contacts.display_name(contact))
  end

  defp contact_assigns(%Input{recipient_email: email, recipient_name: name}),
    do: %{"email" => email, "display_name" => name, "data" => %{}}

  defp render_subject(output, input, assigns) do
    case render_liquid(input.subject || "", assigns) do
      {:ok, rendered} ->
        %{output | subject: rendered}

      {:error, error} ->
        %{output | subject: input.subject, errors: [error | output.errors]}
    end
  end

  defp render_body(output, input = %Input{type: :mjml}, assigns),
    do: BodyRenderer.Mjml.render(output, input, assigns)

  defp render_body(output, input = %Input{type: :html}, assigns),
    do: BodyRenderer.Html.render(output, input, assigns)

  defp render_body(output, input = %Input{type: :text}, assigns),
    do: BodyRenderer.Text.render(output, input, assigns)

  defp render_body(output, input = %Input{type: :block}, assigns),
    do: BodyRenderer.Block.render(output, input, assigns)

  defp render_body(output, input = %Input{type: :markdown}, assigns),
    do: BodyRenderer.Markdown.render(output, input, assigns)

  @doc "Derives a plain-text representation from rendered HTML."
  @spec html_to_text(String.t()) :: String.t()
  def html_to_text(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, tree} ->
        tree |> Floki.text(sep: " ") |> String.replace(~r/\s+/, " ") |> String.trim()

      _ ->
        ""
    end
  end

  @doc """
  Renders an `Input` as a preview: injects a placeholder unsubscribe link and no
  tracking. Same result shape as `render/1`. Callers build the input from their
  source and personalize it with a sample contact.
  """
  @spec render_preview(Input.t()) :: Output.t()
  def render_preview(%Input{} = input) do
    input
    |> put_assign("unsubscribe_link", "#unsubscribe-preview-link")
    |> render()
  end

  defp put_assign(input, key, value) do
    %{input | assigns: Map.put(input.assigns, key, value)}
  end
end
