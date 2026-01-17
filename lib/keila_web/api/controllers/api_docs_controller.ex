defmodule KeilaWeb.ApiDocsController do
  use KeilaWeb, :controller
  use Phoenix.HTML
  import Phoenix.Component

  def show(conn, _) do
    assigns = %{conn: conn}

    content =
      ~H"""
      <!doctype html>
      <html>
        <head>
          <title>Keila API</title>
          <meta charset="utf-8" />
        </head>
        <body>
          <div id="app"></div>
          <div id="api-reference" data-url={Routes.path(@conn, "/api/v1/openapi")}></div>
          <script type="text/javascript">
            document.getElementById("api-reference").dataset.configuration = JSON.stringify({
              withDefaultFonts: false,
              hideClientButton: true,
              servers: [{url: "<%= Routes.url(@conn) %>"}],
              hideModels: true,
              isEditable: false
            })
          </script>
          <script
            defer
            phx-track-static
            type="text/javascript"
            src={Routes.static_path(@conn, "/vendor/scalar/standalone.js")}
          >
          </script>
        </body>
      </html>
      """
      |> Phoenix.HTML.Safe.to_iodata()

    html(conn, content)
  end
end
