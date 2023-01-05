defmodule KeilaWeb.Api.Schemas.MailingsSender do
  @properties %{
    id: %{
      type: :string,
      description: "Sender ID",
      example: "ms_12345"
    },
    name: %{
      type: :string,
      example: "Space Inc. SMTP",
      required: true
    },
    from_email: %{
      type: :string,
      description: "Email address used in the FROM field",
      example: "newsletter@mailings.example.com"
    },
    from_name: %{
      type: :string,
      description: "Name used in the FROM field",
      example: "Space, Inc."
    },
    reply_to_email: %{
      type: :string,
      description: "Email address used in the REPLY_TO field",
      example: "hello@example.com"
    },
    reply_to_name: %{
      type: :string,
      description: "Name used in the REPLY_TO field",
      example: "Space, Inc. Customer Service"
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.MailingsSender.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsSender.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end
