defmodule KeilaWeb.Api.Schemas.MailingsCampaign do
  @properties %{
    id: %{
      type: :string,
      description: "Campaign ID",
      example: "mc_12345"
    },
    subject: %{
      type: :string,
      example: "🚀 Our Space Book is Now Available!",
      required: true
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
          required: true,
          enum: ["markdown", "text", "block", "mjml"],
          example: "markdown"
        },
        do_not_track: %{
          type: :boolean,
          required: false
        }
      }
    },
    template_id: %{
      type: :string
    },
    sender_id: %{
      type: :string,
      required: true,
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

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.Params do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  @allowed_properties [
    :subject,
    :text_body,
    :json_body,
    :mjml_body,
    :settings,
    :template_id,
    :sender_id,
    :segment_id,
    :data
  ]
  build_open_api_schema(@properties, only: @allowed_properties)
end

defmodule KeilaWeb.Api.Schemas.MailingsCampaign.ScheduleParams do
  use KeilaWeb.Api.Schema

  @properties KeilaWeb.Api.Schemas.MailingsCampaign.properties()
  build_open_api_schema(@properties, only: [:scheduled_for])
end
