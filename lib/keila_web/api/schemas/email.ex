defmodule KeilaWeb.Api.Schemas.Email do
  @properties %{
    type: %{
      type: :string,
      enum: [:text, :markdown, :mjml, :html],
      example: "markdown"
    },
    subject: %{
      type: :string,
      example: "Welcome to our newsletter!"
    },
    preview_text: %{
      type: :string
    },
    text_body: %{
      type: :string,
      example: "Hi {{ contact.first_name }}, thanks for subscribing."
    },
    text_content: %{
      type: :map,
      description:
        "Map of named content slots for text templates that declare <keila-content> slots.",
      example: %{"main" => "Hi {{ contact.first_name }}!"}
    },
    html_body: %{
      type: :string,
      example: "<p>Hi {{ contact.first_name }}, thanks for subscribing.</p>"
    },
    html_content: %{
      type: :map,
      description:
        "Map of named content slots for HTML templates that declare <keila-content> slots.",
      example: %{"main" => "<p>Hi {{ contact.first_name }}!</p>"}
    },
    mjml_body: %{
      type: :string,
      example:
        "<mjml><mj-body><mj-section><mj-column><mj-text>Hi!</mj-text></mj-column></mj-section></mj-body></mjml>"
    },
    mjml_content: %{
      type: :map,
      description:
        "Map of named content slots for MJML templates that declare <keila-content> slots.",
      example: %{
        "main" =>
          "<mj-section><mj-column><mj-text>Hi {{ contact.first_name }}!</mj-text></mj-column></mj-section>"
      }
    },
    template_id: %{
      type: :string,
      example: "tpl_12345"
    }
  }

  def properties() do
    @properties
  end
end
