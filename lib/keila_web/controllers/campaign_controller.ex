defmodule KeilaWeb.CampaignController do
  use KeilaWeb, :controller
  alias Keila.{Mailings, Templates}
  import Ecto.Changeset
  import Phoenix.LiveView.Controller

  plug :authorize when action not in [:index, :new, :post_new, :delete]

  @default_text_body File.read!("priv/email_templates/default-text-content.txt")
  @default_markdown_body File.read!("priv/email_templates/default-markdown-content.md")

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    campaigns = Mailings.get_project_campaigns(current_project(conn).id)

    conn
    |> assign(:campaigns, campaigns)
    |> put_meta(:title, gettext("Campaigns"))
    |> render("index.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    render_new(conn, change(%Mailings.Campaign{}))
  end

  @spec post_new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_new(conn, params) do
    project = current_project(conn)

    params =
      (params["campaign"] || %{})
      |> put_default_body()

    case Mailings.create_campaign(project.id, params) do
      {:ok, campaign} ->
        redirect(conn, to: Routes.campaign_path(conn, :edit, project.id, campaign.id))

      {:error, changeset} ->
        render_new(conn, 400, changeset)
    end
  end

  defp render_new(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> put_meta(:title, gettext("New Campaign"))
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  defp put_default_body(params) do
    # TODO Maybe this would be better implemented as a Context module function
    case get_in(params, ["settings", "type"]) do
      "markdown" -> Map.put(params, "text_body", @default_markdown_body)
      _ -> Map.put(params, "text_body", @default_text_body)
    end
  end

  @spec clone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def clone(conn, _params) do
    render_clone(conn, change(conn.assigns.campaign))
  end

  @spec post_clone(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_clone(conn, params) do
    project = current_project(conn)
    campaign = conn.assigns.campaign
    params = params["campaign"] || %{}

    case Mailings.clone_campaign(campaign.id, params) do
      {:ok, campaign} ->
        redirect(conn, to: Routes.campaign_path(conn, :edit, project.id, campaign.id))

      {:error, changeset} ->
        render_clone(conn, 400, changeset)
    end
  end

  defp render_clone(conn, status \\ 200, changeset) do
    conn
    |> put_status(status)
    |> put_meta(:title, gettext("Clone Campaign"))
    |> assign(:changeset, changeset)
    |> render("clone.html")
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, _params) do
    project = current_project(conn)
    campaign = conn.assigns.campaign

    if is_nil(campaign.sent_at) do
      senders = Mailings.get_project_senders(project.id)
      templates = Templates.get_project_templates(project.id)

      live_render(conn, KeilaWeb.CampaignEditLive,
        session: %{
          "current_project" => project,
          "campaign" => campaign,
          "senders" => senders,
          "templates" => templates
        }
      )
    else
      redirect(conn, to: Routes.campaign_path(conn, :stats, project.id, campaign.id))
    end
  end

  @spec post_edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def post_edit(conn, params) do
    project = current_project(conn)
    campaign = conn.assigns.campaign

    already_sent? = not is_nil(campaign.sent_at)

    schedule_params = params["schedule"] || %{}
    schedule? = schedule_params["schedule"] == "true" || schedule_params["cancel"] == "true"

    send? = params["send"] == "true"

    params = params["campaign"] || %{}

    cond do
      already_sent? ->
        redirect(conn, to: Routes.campaign_path(conn, :stats, project.id, campaign.id))

      send? ->
        update_and_send(conn, params)

      schedule? ->
        update_and_schedule(conn, params, schedule_params)

      true ->
        update(conn, params)
    end
  end

  defp update(conn, params) do
    project = current_project(conn)

    do_update(conn, params, false, fn _campaign ->
      redirect(conn, to: Routes.campaign_path(conn, :index, project.id))
    end)
  end

  defp update_and_send(conn, params) do
    project = current_project(conn)

    do_update(conn, params, true, fn campaign ->
      Mailings.deliver_campaign_async(campaign.id)
      redirect(conn, to: Routes.campaign_path(conn, :stats, project.id, campaign.id))
    end)
  end

  defp update_and_schedule(conn, params, schedule_params) do
    project = current_project(conn)

    scheduled_for =
      with "true" <- schedule_params["schedule"],
           {:ok, date} <- Date.from_iso8601(schedule_params["date"]),
           {:ok, time} <- Time.from_iso8601(schedule_params["time"] <> ":00"),
           {:ok, datetime} <- DateTime.new(date, time, schedule_params["timezone"]),
           {:ok, scheduled_for} <- DateTime.shift_zone(datetime, "Etc/UTC") do
        scheduled_for
      else
        _ -> nil
      end

    do_update(conn, params, true, fn campaign ->
      case Mailings.schedule_campaign(campaign.id, %{"scheduled_for" => scheduled_for}) do
        {:error, changeset} ->
          render_error(conn, params, changeset)

        {:ok, _campaign} ->
          redirect(conn, to: Routes.campaign_path(conn, :index, project.id))
      end
    end)
  end

  defp do_update(conn, params, use_send_changeset?, callback) do
    campaign_id = conn.assigns.campaign.id

    Mailings.update_campaign(campaign_id, params, use_send_changeset?)
    |> case do
      {:ok, campaign} -> callback.(campaign)
      {:error, changeset} -> render_error(conn, params, changeset)
    end
  end

  defp render_error(conn, params, changeset) do
    project = current_project(conn)
    campaign = conn.assigns.campaign
    senders = Mailings.get_project_senders(project.id)

    live_render(conn, KeilaWeb.CampaignEditLive,
      session: %{
        "current_project" => project,
        "campaign" => campaign,
        "params" => params,
        "senders" => senders,
        "changeset" => changeset
      }
    )
  end

  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, _params) do
    project = current_project(conn)
    campaign = conn.assigns.campaign
    account = Keila.Accounts.get_user_account(conn.assigns.current_user.id)

    live_render(conn, KeilaWeb.CampaignStatsLive,
      session: %{"current_project" => project, "campaign" => campaign, "account" => account}
    )
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, params) do
    ids =
      case get_in(params, ["campaign", "id"]) do
        ids when is_list(ids) -> ids
        id when is_binary(id) -> [id]
      end

    case get_in(params, ["campaign", "require_confirmation"]) do
      "true" ->
        render_delete_confirmation(conn, ids)

      _ ->
        :ok = Mailings.delete_project_campaigns(current_project(conn).id, ids)

        redirect(conn, to: Routes.campaign_path(conn, :index, current_project(conn).id))
    end
  end

  defp render_delete_confirmation(conn, ids) do
    campaigns =
      Mailings.get_project_campaigns(current_project(conn).id)
      |> Enum.filter(&(&1.id in ids))

    conn
    |> put_meta(:title, gettext("Confirm campaign Deletion"))
    |> assign(:campaigns, campaigns)
    |> render("delete.html")
  end

  defp current_project(conn), do: conn.assigns.current_project

  defp authorize(conn, _) do
    project_id = current_project(conn).id
    campaign_id = conn.path_params["id"]

    case Mailings.get_project_campaign(project_id, campaign_id) do
      nil ->
        conn
        |> put_status(404)
        |> halt()

      campaign ->
        assign(conn, :campaign, campaign)
    end
  end
end
