defmodule KeilaWeb.Api.Schemas.Template do
  @properties %{
    id: %{
      type: :string,
      description: "Template ID",
      example: "tpl_12345"
    },
    name: %{
      type: :string,
      example: "Welcome Email"
    },
    type: %{
      type: :string,
      enum: ["text", "html", "mjml", "hybrid"],
      example: "mjml"
    },
    mjml_body: %{
      type: :string,
      example: """
      <mjml>
        <mj-body>
          <keila-content name="main">
            <mj-text>Hey {{ contact.first_name }}.</mj-text>
          </keila-content>
          <mj-text><a href="{{ unsubscribe_link }}">Unsubscribe</a></mj-text>
        </mj-body>
      </mjml>
      """
    },
    html_body: %{
      type: :string,
      example: """
      <html>
        <body>
          <keila-content name="main">
            <p>Hey {{ contact.first_name }}.</p>
          </keila-content>
          <p><a href="{{ unsubscribe_link }}">Unsubscribe</a></p>
        </body>
      </html>
      """
    },
    text_body: %{
      type: :string,
      example: """
      <keila-content name="main">
      Hey {{ contact.first_name }}.
      </keila-content>

      --
      Unsubscribe: {{ unsubscribe_link }}
      """
    },
    styles: %{
      type: :string
    },
    assigns: %{
      type: :map
    },
    mjml_content_slots: %{
      type: :array,
      description:
        "Slots defined with <keila-content> tags in `mjml_body`. Read-only; present only for `mjml` templates.",
      items: %{
        name: %{type: :string, example: "main"},
        default_content: %{type: :string, example: "<mj-text>\n  Welcome!\n</mj-text>\n"}
      }
    },
    html_content_slots: %{
      type: :array,
      description:
        "Slots defined with <keila-content> tags in `html_body`. Read-only; present only for `html` templates.",
      items: %{
        name: %{type: :string, example: "main"},
        default_content: %{type: :string, example: "<p>Welcome!</p>"}
      }
    },
    text_content_slots: %{
      type: :array,
      description:
        "Slots defined with <keila-content> tags in `text_body`. Read-only; present only for `text` templates.",
      items: %{
        name: %{type: :string, example: "main"},
        default_content: %{type: :string, example: "Welcome!"}
      }
    },
    inserted_at: %{
      type: :string,
      format: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
    },
    updated_at: %{
      type: :string,
      format: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.Template.Response do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Template.properties()
  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.Template.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Template.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end

defmodule KeilaWeb.Api.Schemas.Template.CreateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Template.properties()
  @allowed_properties [:name, :type, :mjml_body, :html_body, :text_body, :styles, :assigns]
  build_open_api_schema(@properties, only: @allowed_properties, required: [:name, :type])
end

defmodule KeilaWeb.Api.Schemas.Template.UpdateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.Template.properties()
  @allowed_properties [:name, :mjml_body, :html_body, :text_body, :styles, :assigns]
  build_open_api_schema(@properties, only: @allowed_properties)
end
