defmodule KeilaWeb.ApiSenderController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Mailings
  alias KeilaWeb.Api.Schemas

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  tags(["Sender"])

  operation(:index,
    summary: "Index senders",
    description: "Retrieve all senders from your project.",
    parameters: [],
    responses: [
      ok: {"Sender response", "application/json", Schemas.MailingsSender.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    senders =
      Mailings.get_project_senders(project_id(conn))
      |> then(fn senders ->
        count = Enum.count(senders)
        %Keila.Pagination{data: senders, page: 0, page_count: 1, count: count}
      end)

    render(conn, "senders.json", %{senders: senders})
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
