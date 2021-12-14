defmodule KeilaWeb.ApiController do
  use KeilaWeb, :controller

  alias Keila.Auth
  alias Keila.Auth.Token
  alias Keila.Projects
  alias KeilaWeb.ApiNormalizer
  alias Keila.Contacts
  alias Keila.Mailings

  plug :authorize

  #
  # Contact functions
  #

  plug ApiNormalizer, [normalize: [:pagination, :contacts_filter]] when action == :index_contacts

  plug ApiNormalizer,
       [normalize: [{:data, :contact}]] when action in [:create_contact, :update_contact]

  @spec index_contacts(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index_contacts(conn, _params) do
    contacts =
      Contacts.get_project_contacts(project_id(conn),
        paginate: conn.assigns.pagination,
        filter: conn.assigns.filter
      )

    render(conn, "contacts.json", %{contacts: contacts})
  end

  def create_contact(conn, _params) do
    case Contacts.create_contact(project_id(conn), conn.assigns.data) do
      {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
      {:error, changeset} -> send_changeset_error(conn, changeset)
    end
  end

  def show_contact(conn, %{"id" => id}) do
    case Contacts.get_project_contact(project_id(conn), id) do
      contact = %Contacts.Contact{} -> render(conn, "contact.json", %{contact: contact})
      nil -> send_404(conn)
    end
  end

  def update_contact(conn, %{"id" => id}) do
    if Contacts.get_project_contact(project_id(conn), id) do
      case Contacts.update_contact(id, conn.assigns.data) do
        {:ok, contact} -> render(conn, "contact.json", %{contact: contact})
        {:error, changeset} -> send_changeset_error(conn, changeset)
      end
    else
      send_404(conn)
    end
  end

  def delete_contact(conn, %{"id" => id}) do
    Contacts.delete_project_contacts(project_id(conn), filter: %{"id" => id})

    conn
    |> put_status(204)
  end

  #
  # Campaign functions
  #

  plug ApiNormalizer,
       [normalize: [{:data, :campaign}]]
       when action in [:create_campaign, :update_campaign, :schedule_campaign]

  @spec index_campaigns(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index_campaigns(conn, _params) do
    campaigns =
      Mailings.get_project_campaigns(project_id(conn))
      |> then(fn campaigns ->
        count = Enum.count(campaigns)
        %Keila.Pagination{data: campaigns, page: 0, page_count: 1, count: count}
      end)

    render(conn, "campaigns.json", %{campaigns: campaigns})
  end

  def create_campaign(conn, _params) do
    case Mailings.create_campaign(project_id(conn), conn.assigns.data) do
      {:ok, campaign} -> render(conn, "campaign.json", %{campaign: campaign})
      {:error, changeset} -> send_changeset_error(conn, changeset)
    end
  end

  def show_campaign(conn, %{"id" => id}) do
    case Mailings.get_project_campaign(project_id(conn), id) do
      campaign = %Mailings.Campaign{} -> render(conn, "campaign.json", %{campaign: campaign})
      nil -> send_404(conn)
    end
  end

  def update_campaign(conn, %{"id" => id}) do
    project_id = project_id(conn)

    with campaign = %Mailings.Campaign{} <- Mailings.get_project_campaign(project_id, id) do
      settings_id = campaign.settings.id
      params = put_in(conn.assigns.data, ["settings", "id"], settings_id)

      case Mailings.update_campaign(id, params) do
        {:ok, campaign} -> render(conn, "campaign.json", %{campaign: campaign})
        {:error, changeset} -> send_changeset_error(conn, changeset)
      end
    else
      _ -> send_404(conn)
    end
  end

  def delete_campaign(conn, %{"id" => id}) do
    Mailings.delete_project_campaigns(project_id(conn), [id])

    conn
    |> put_status(204)
  end

  def deliver_campaign(conn, %{"id" => id}) do
    # TODO immediate feedback on missing sender or insufficient credits
    campaign = Mailings.get_project_campaign(project_id(conn), id)

    if campaign do
      Mailings.deliver_campaign_async(campaign.id)
      put_status(conn, 204)
    else
      send_404(conn)
    end
  end

  def schedule_campaign(conn, params = %{"id" => id}) do
    campaign = Mailings.get_project_campaign(project_id(conn), id)

    if campaign do
      scheduled_for = get_in(params, ["data", "scheduledFor"])

      case Mailings.schedule_campaign(campaign.id, %{scheduled_for: scheduled_for}) do
        {:ok, campaign} -> render(conn, "campaign.json", campaign: campaign)
        {:error, changeset} -> send_changeset_error(conn, changeset)
      end
    else
      send_404(conn)
    end
  end

  #
  # Segment functions
  #

  plug ApiNormalizer,
       [normalize: [{:data, :segment}]]
       when action in [:create_segment, :update_segment]

  def index_segments(conn, _params) do
    segments =
      Contacts.get_project_segments(project_id(conn))
      |> then(fn segments ->
        count = Enum.count(segments)
        %Keila.Pagination{data: segments, page: 0, page_count: 1, count: count}
      end)

    render(conn, "segments.json", %{segments: segments})
  end

  def create_segment(conn, _params) do
    case Contacts.create_segment(project_id(conn), conn.assigns.data) do
      {:ok, segment} -> render(conn, "segment.json", %{segment: segment})
      {:error, changeset} -> send_changeset_error(conn, changeset)
    end
  end

  def show_segment(conn, %{"id" => id}) do
    case Contacts.get_project_segment(project_id(conn), id) do
      segment = %Contacts.Segment{} -> render(conn, "segment.json", %{segment: segment})
      nil -> send_404(conn)
    end
  end

  def update_segment(conn, %{"id" => id}) do
    if Contacts.get_project_segment(project_id(conn), id) do
      case Contacts.update_segment(id, conn.assigns.data) do
        {:ok, segment} -> render(conn, "segment.json", %{segment: segment})
        {:error, changeset} -> send_changeset_error(conn, changeset)
      end
    else
      send_404(conn)
    end
  end

  def delete_segment(conn, %{"id" => id}) do
    Contacts.delete_project_segments(project_id(conn), [id])

    conn
    |> put_status(204)
  end

  defp send_403(conn) do
    conn
    |> put_status(403)
    |> render("errors.json", %{errors: [[status: 403, title: "Not authorized"]]})
  end

  defp send_404(conn) do
    conn
    |> put_status(404)
    |> render("errors.json", %{errors: [[status: 404, title: "Not found"]]})
  end

  defp send_changeset_error(conn, changeset) do
    conn
    |> put_status(400)
    |> render("errors.json", %{errors: [[status: 400, detail: changeset]]})
  end

  defp project_id(conn), do: conn.assigns.current_project.id

  defp authorize(conn, _) do
    with ["Bearer: " <> token] <- get_req_header(conn, "authorization"),
         %Token{data: %{"project_id" => project_id}, user_id: user_id} <-
           Auth.find_token(token, "api"),
         project = %Projects.Project{} <- Projects.get_user_project(user_id, project_id) do
      conn
      |> assign(:current_project, project)
    else
      _ -> conn |> send_403() |> halt()
    end
  end
end
