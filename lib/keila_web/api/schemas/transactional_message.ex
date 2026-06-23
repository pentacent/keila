defmodule KeilaWeb.Api.Schemas.TransactionalMessage do
  @properties %{
    id: %{
      type: :string,
      description: "Message ID",
      example: "nmr_12345"
    },
    type: %{
      type: :string,
      enum: ["text", "html", "mjml"],
      example: "html"
    },
    recipient_email: %{
      type: :string,
      example: "jane.doe@example.com"
    },
    recipient_name: %{
      type: :string,
      example: "Jane Doe"
    },
    cc: %{
      any_of: [:string, {:array, :string}],
      description:
        "CC recipients as an RFC 5322 address list, e.g. `Jane <jane@example.com>, john@example.com`. May also be given as a JSON array of such strings.",
      example: "Jane <jane@example.com>, john@example.com"
    },
    bcc: %{
      any_of: [:string, {:array, :string}],
      description: "BCC recipients as an RFC 5322 address list (see `cc`).",
      example: "jane@example.com"
    },
    contact_id: %{
      type: :string,
      example: "nc_12345"
    },
    external_contact_id: %{
      type: :string,
      example: "customer-1234"
    },
    subject: %{
      type: :string,
      example: "Your order is confirmed"
    },
    text_body: %{
      type: :string,
      example: "Hi {{ contact.first_name }}, thanks for your order."
    },
    html_body: %{
      type: :string,
      example: "<p>Hi {{ contact.first_name }}, thanks for your order.</p>"
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
    html_content: %{
      type: :map,
      description:
        "Map of named content slots for HTML templates that declare <keila-content> slots.",
      example: %{"main" => "<p>Hi {{ contact.first_name }}!</p>"}
    },
    text_content: %{
      type: :map,
      description:
        "Map of named content slots for text templates that declare <keila-content> slots.",
      example: %{"main" => "Hi {{ contact.first_name }}!"}
    },
    assigns: %{
      type: :map,
      description: "Values made available to Liquid interpolation in the subject and body.",
      example: %{"magic_link" => "https://example.com/..."}
    },
    template_id: %{
      type: :string,
      example: "ntpl_12345"
    },
    sender_id: %{
      type: :string,
      example: "ms_12345"
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.TransactionalMessage.SendParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.TransactionalMessage.properties()
  @allowed [
    :type,
    :recipient_email,
    :recipient_name,
    :cc,
    :bcc,
    :contact_id,
    :external_contact_id,
    :subject,
    :text_body,
    :html_body,
    :mjml_body,
    :mjml_content,
    :html_content,
    :text_content,
    :assigns,
    :template_id,
    :sender_id
  ]

  build_open_api_schema(@properties, only: @allowed, required: [:type, :sender_id])
end

defmodule KeilaWeb.Api.Schemas.TransactionalMessage.Response do
  use KeilaWeb.Api.Schema

  @properties %{
    id: KeilaWeb.Api.Schemas.TransactionalMessage.properties().id,
    recipient_email: KeilaWeb.Api.Schemas.TransactionalMessage.properties().recipient_email,
    subject: KeilaWeb.Api.Schemas.TransactionalMessage.properties().subject
  }

  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.TransactionalMessage.RendererOutputResponse do
  use KeilaWeb.Api.Schema

  @properties %{
    subject: KeilaWeb.Api.Schemas.TransactionalMessage.properties().subject,
    html_body: KeilaWeb.Api.Schemas.TransactionalMessage.properties().html_body,
    text_body: KeilaWeb.Api.Schemas.TransactionalMessage.properties().text_body
  }

  build_open_api_schema(@properties)
end
