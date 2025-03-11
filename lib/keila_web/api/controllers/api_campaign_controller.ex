defmodule KeilaWeb.ApiCampaignController do
  use KeilaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias Keila.Mailings
  alias KeilaWeb.Api.Schemas
  alias KeilaWeb.Api.Errors

  plug KeilaWeb.Api.Plugs.Authorization
  plug KeilaWeb.Api.Plugs.Normalization

  # Open API Tags
  tags(["Campaign"])

  operation(:index,
    summary: "Index campaigns",
    description: "Retrieve all campaigns from your project.",
    parameters: [],
    responses: [
      ok: {"Campaign index response", "application/json", Schemas.MailingsCampaign.IndexResponse}
    ]
  )

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    campaigns =
      Mailings.get_project_campaigns(project_id(conn))
      |> then(fn campaigns ->
        count = Enum.count(campaigns)
        %Keila.Pagination{data: campaigns, page: 0, page_count: 1, count: count}
      end)

    render(conn, "campaigns.json", %{campaigns: campaigns})
  end

  operation(:create,
    summary: "Create Campaign",
    parameters: [],
    request_body: {"Campaign params", "application/json", Schemas.MailingsCampaign.CreateParams},
    responses: [
      ok: {"Campaign response", "application/json", Schemas.MailingsCampaign.Response}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    case Mailings.create_campaign(project_id(conn), conn.body_params.data) do
      {:ok, campaign} -> render(conn, "campaign.json", %{campaign: campaign})
      {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
    end
  end

  operation(:show,
    summary: "Show Campaign",
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    responses: [
      ok: {"Campaign response", "application/json", Schemas.MailingsCampaign.Response}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{id: id}) do
    case Mailings.get_project_campaign(project_id(conn), id) do
      campaign = %Mailings.Campaign{} -> render(conn, "campaign.json", %{campaign: campaign})
      nil -> Errors.send_404(conn)
    end
  end

  operation(:update,
    summary: "Update Campaign",
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    request_body: {"Campaign params", "application/json", Schemas.MailingsCampaign.UpdateParams},
    responses: [
      ok: {"Campaign response", "application/json", Schemas.MailingsCampaign.Response}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{id: id}) do
    project_id = project_id(conn)

    with campaign = %Mailings.Campaign{} <- Mailings.get_project_campaign(project_id, id) do
      settings_params =
        campaign.settings
        |> Mailings.Campaign.Settings.changeset(conn.body_params.data[:settings] || %{})
        |> Ecto.Changeset.apply_changes()
        |> Map.from_struct()

      params = Map.put(conn.body_params.data, :settings, settings_params)

      case Mailings.update_campaign(id, params) do
        {:ok, campaign} -> render(conn, "campaign.json", %{campaign: campaign})
        {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
      end
    else
      _ -> Errors.send_404(conn)
    end
  end

  operation(:delete,
    summary: "Delete Campaign",
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    responses: %{
      204 => "Campaign was deleted successfully or didn’t exist."
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{id: id}) do
    Mailings.delete_project_campaigns(project_id(conn), [id])

    conn
    |> send_resp(:no_content, "")
  end

  operation(:deliver,
    summary: "Deliver Campaign",
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    responses: %{
      202 =>
        {"Campaign delivery queued", "application/json",
         Schemas.MailingsCampaign.DeliveryQueuedResponse}
    }
  )

  @spec deliver(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deliver(conn, %{id: id}) do
    # TODO immediate feedback on missing sender or insufficient credits
    campaign = Mailings.get_project_campaign(project_id(conn), id)

    if campaign do
      Mailings.deliver_campaign_async(campaign.id)

      conn
      |> put_status(202)
      |> render("delivery_queued.json", %{campaign: campaign})
    else
      Errors.send_404(conn)
    end
  end

  operation(:schedule,
    summary: "Schedule Campaign",
    parameters: [id: [in: :path, type: :string, description: "Campaign ID"]],
    request_body:
      {"Schedule params", "application/json", Schemas.MailingsCampaign.ScheduleParams},
    responses: %{
      ok: {"Campaign response", "application/json", Schemas.MailingsCampaign.Response}
    }
  )

  @spec schedule(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def schedule(conn, %{id: id}) do
    campaign = Mailings.get_project_campaign(project_id(conn), id)

    if campaign do
      scheduled_for = conn.body_params.data[:scheduled_for]

      case Mailings.schedule_campaign(campaign.id, %{scheduled_for: scheduled_for}) do
        {:ok, campaign} -> render(conn, "campaign.json", campaign: campaign)
        {:error, changeset} -> Errors.send_changeset_error(conn, changeset)
      end
    else
      Errors.send_404(conn)
    end
  end

  defp project_id(conn), do: conn.assigns.current_project.id
end
