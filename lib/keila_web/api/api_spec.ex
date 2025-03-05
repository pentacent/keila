defmodule KeilaWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server, SecurityScheme}
  alias KeilaWeb.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
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
