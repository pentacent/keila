defmodule KeilaWeb.Api.Schemas.MailingsCampaign do
  @properties %{
    id: %{
      type: :string,
      description: "Campaign ID",
      example: "mc_12345"
    },
    subject: %{
      type: :string,
      example: "🚀 Our Space Book is Now Available!"
    },
    text_body: %{
      type: :string,
      example: """
      Hey {{ contact.first_name }}, are you excited for our Space Book?

      […]

      ## All Books by Acme Space Corp:
      {% for book in campaign.data.books %}
        - {{ book.title }}: [More info]({{ book.url }})
      {% endfor %}
      """
    },
    json_body: %{
      type: :map,
      example: %{
        "blocks" => [
          %{
            "id" => "ff0011",
            "type" => "paragraph",
            "data" => %{"text" => "Hello, I am a block campaign!"}
          }
        ]
      }
    },
    mjml_body: %{
      type: :string,
      example: """
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>Hello I’m an MJML campaign!</mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
      """
    },
    html_body: %{
      type: :string,
      example: """
      <!doctype html>
      <html>
        <body>
          <h1>Hello {{ contact.first_name }}!</h1>
        </body>
      </html>
      """
    },
    mjml_content: %{
      type: :map,
      description: "Map of MJML content slots, keyed by slot name.",
      example: %{"main" => "<mj-text>Hi {{ contact.first_name }}!</mj-text>"}
    },
    html_content: %{
      type: :map,
      description: "Map of HTML content slots, keyed by slot name.",
      example: %{"main" => "<p>Hi {{ contact.first_name }}!</p>"}
    },
    text_content: %{
      type: :map,
      description: "Map of text content slots, keyed by slot name.",
      example: %{"main" => "Hi {{ contact.first_name }}!"}
    },
    data: %{
      type: :map,
      example: %{
        "books" => [
          %{"title" => "Space Book", "url" => "books.books/spacebook"},
          %{"title" => "Earth Book", "url" => "books.books/earthbook"}
        ]
      }
    },
    settings: %{
      type: :map,
      properties: %{
        type: %{
          type: :string,
          enum: ["markdown", "text", "block", "mjml", "html"],
          example: "markdown"
        },
        do_not_track: %{
          type: :boolean
        }
      }
    },
    template_id: %{
      type: :string
    },
    sender_id: %{
      type: :string,
      example: "ms_12345"
    },
    segment_id: %{
      type: :string,
      example: "sgm_12345"
    },
    sent_at: %{
      type: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
    },
    scheduled_for: %{
      type: :utc_datetime,
      example: DateTime.utc_now() |> DateTime.to_iso8601()
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
    },
    preview_text: %{
      type: :string,
      example: "Hello, I am a preview campaign!"
    }
  }

  def properties() do
    @properties
  end
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.Response do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  build_open_api_schema(@properties)
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.IndexResponse do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  build_open_api_schema(@properties, list: true, with_pagination: true)
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.CreateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  @allowed_properties [
    :subject,
    :text_body,
    :json_body,
    :mjml_body,
    :html_body,
    :mjml_content,
    :html_content,
    :text_content,
    :settings,
    :template_id,
    :sender_id,
    :segment_id,
    :data,
    :preview_text
  ]
  build_open_api_schema(@properties,
    only: @allowed_properties,
    required: [:subject, :settings, {[:settings], [:type]}]
  )
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.UpdateParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  @allowed_properties [
    :subject,
    :text_body,
    :json_body,
    :mjml_body,
    :html_body,
    :mjml_content,
    :html_content,
    :text_content,
    :settings,
    :template_id,
    :sender_id,
    :segment_id,
    :data,
    :preview_text
  ]
  build_open_api_schema(@properties, only: @allowed_properties)
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.ScheduleParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  build_open_api_schema(@properties, only: [:scheduled_for])
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.DeliveryQueuedResponse do
  use KeilaWeb.Api.Schema

  build_open_api_schema(%{
    delivery_queued: %{
      type: :boolean,
      enum: [true],
      description: """
      This indicates that the delivery of the campaign will be processed asynchronously.

      **Note**: If the campaign is invalid (e.g. missing a sender) or if your account has
      insufficient credits, the campaign will not be delivered regardless of the response from the endpoint.
      """
    },
    campaign_id: %{
      type: :string,
      description: "Campaign ID",
      example: "mc_12345"
    }
  })
end
