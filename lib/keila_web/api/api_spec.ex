defmodule KeilaWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server, SecurityScheme, Tag}
  alias KeilaWeb.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      tags: [
        %Tag{
          name: "Contacts",
          description: """
          A contact is a potential recipient for your emails: contacts are comprised
          of an email address along with an optional first and last name and arbitrary
          custom data.
          """
        },
        %Tag{
          name: "Segment",
          description: """
          A segment is a named, reusable filter over your contacts. It selects a
          subset of contacts based on their attributes and data, allowing you
          to target a part of your contact list when sending a campaign.
          """
        },
        %Tag{
          name: "Sender",
          description: """
          A sender is an identity and configuration set for delivering email.
          """
        },
        %Tag{
          name: "Campaign",
          description: """
          A campaign is an email message sent to many contacts at once
          The content can be authored as text, Markdown, blocks, MJML, or HTML.
          """
        },
        %Tag{
          name: "Template",
          description: """
          A template is a reusable email design that campaigns and messages can
          build on. Each template has a `type` — `text`, `html`, `mjml`, or
          `hybrid`. Templates can define named content slots that a campaign or
          transactional message fills in with its own content.
          """
        },
        %Tag{
          name: "Forms",
          description: """
          A form is a hosted sign-up form. It collects an email address and
          other fields from visitors and turns each submission into a contact.
          Forms can be configured with double opt-in confirmation and a welcome message.
          """
        },
        %Tag{
          name: "Transactional Messages",
          description: """
          Transactional Messages are sent to a single recipient and used for things
          like receipts, account confirmations, or password resets.
          """
        }
      ],
      info: %Info{
        title: "Keila API",
        version: "1.0",
        description:
          "The Keila API allows you to manage your contacts, create newsletter campaigns, manage and submit contact forms."
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}}
      },
      security: [%{"authorization" => []}]
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
