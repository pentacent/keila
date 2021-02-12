defmodule KeilaWeb.CampaignControllerTest do
  use KeilaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Keila.Mailings
  @endpoint KeilaWeb.Endpoint

  defp setup_conn_and_project(conn) do
    conn = with_login(conn)
    project = setup_project(conn)
    %{conn: conn, project: project}
  end

  describe "GET /projects/:p_id/campaigns" do
    @tag :campaign_controller
    test "list campaigns", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)

      campaigns = insert_n!(:mailings_campaign, 5, fn _ -> %{project_id: project.id} end)
      conn = get(conn, Routes.campaign_path(conn, :index, project.id))
      assert html_response = html_response(conn, 200)
      for campaign <- campaigns, do: assert(html_response =~ campaign.subject)
    end

    @tag :campaign_controller
    test "show empty state", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      conn = get(conn, Routes.campaign_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first campaign"
    end
  end

  describe "GET /projects/:p_id/campaigns/new" do
    @tag :campaign_controller
    test "shows creation page with subject form", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      conn = get(conn, Routes.campaign_path(conn, :new, project.id))
      assert html_response(conn, 200) =~ ~r{New Campaign\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/campaigns/new" do
    @tag :campaign_controller
    test "creates new campaign and redirects", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)

      params = %{"subject" => "My Campaign", "settings" => %{"type" => "text"}}
      conn = post(conn, Routes.campaign_path(conn, :post_new, project.id, campaign: params))
      assert redirected_to(conn, 302) =~ Routes.campaign_path(conn, :edit, project.id, "mc_")
    end

    @tag :campaign_controller
    test "validates params", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      params = %{"subject" => "", "settings" => %{"type" => "text"}}
      conn = post(conn, Routes.campaign_path(conn, :post_new, project.id, campaign: params))
      assert html_response(conn, 400) =~ ~r{can&#39;t be blank}
    end
  end

  describe "LV /projects/:p_id/campaigns/:id" do
    @tag :campaign_controller
    test "shows edit form", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))

      assert html_response(conn, 200) =~ ~r{Edit Campaign\s*</h1>}
    end

    @tag :campaign_controller
    test "shows campaign preview", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id, text_body: "Hello there!")
      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, html} = live(conn)

      assert html =~ "Hello there"

      assert lv
             |> element("#campaign")
             |> render_change(%{
               "campaign" => %{"text_body" => "Foo {{ invalid_assign | default: \"Bar\"}}"}
             }) =~
               "Foo Bar"
    end
  end

  describe "PUT /projects/:p_id/campaigns/:id" do
    @tag :campaign_controller
    test "updates campaign and redirects to index", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      params = %{"subject" => "Foo Bar"}

      conn =
        put(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id, campaign: params))

      assert redirected_to(conn, 302) == Routes.campaign_path(conn, :index, project.id)
      assert %{subject: "Foo Bar"} = Mailings.get_campaign(campaign.id)
    end

    @tag :campaign_controller
    test "delivers campaign and redirects to stats page", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      params = %{"send" => "true"}

      conn =
        put(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id, campaign: params))

      assert redirected_to(conn, 302) ==
               Routes.campaign_path(conn, :stats, project.id, campaign.id)

      # Avoid database pool error when exiting test before transaction has
      # finished
      :timer.sleep(500)
    end
  end

  describe "LV /projects/:p_id/campaigns/:id/stats" do
    @tag :campaign_controller
    test "shows delivery progress and success message", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)

      campaign =
        insert!(:mailings_campaign,
          project_id: project.id,
          sender: build(:mailings_sender, config: %{type: "test"})
        )

      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      Mailings.deliver_campaign(campaign.id)
      conn = get(conn, Routes.campaign_path(conn, :stats, project.id, campaign.id))
      {:ok, lv, html} = live(conn)
      assert html =~ "This campaign is currently being sent out."

      Oban.drain_queue(queue: :mailer, with_safety: false)
      :timer.sleep(1_500)
      assert render(lv) =~ "This campaign has been successfully sent out to 10 recipients."
    end
  end

  describe "DELETE /projects/" do
    @tag :campaign_controller
    test "deletes campaign", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      conn =
        delete(
          conn,
          Routes.campaign_path(conn, :delete, project.id, campaign: %{"id" => [campaign.id]})
        )

      assert redirected_to(conn, 302) == Routes.campaign_path(conn, :index, project.id)
      assert nil == Mailings.get_campaign(campaign.id)
    end

    @tag :campaign_controller
    test "shows confirmation page", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)

      conn =
        delete(
          conn,
          Routes.campaign_path(conn, :delete, project.id,
            campaign: %{"id" => [campaign.id], "require_confirmation" => "true"}
          )
        )

      refute nil == Mailings.get_campaign(campaign.id)
      assert html_response(conn, 200) =~ ~r{Delete Campaigns\?\s*</h1>}
    end
  end

  describe "GET /projects/:p_id/campaigns/:id/clone" do
    @tag :campaign_controller
    test "shows form for cloning", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      conn = get(conn, Routes.campaign_path(conn, :clone, project.id, campaign.id))
      assert html_response(conn, 200) =~ ~r{Clone Campaign\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/campaigns/:id/clone" do
    @tag :campaign_controller
    test "clones campaign and redirects to edit page", %{conn: conn} do
      %{conn: conn, project: project} = setup_conn_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      params = %{"subject" => "Foo bar"}

      conn =
        post(conn, Routes.campaign_path(conn, :clone, project.id, campaign.id, campaign: params))

      assert redirected_to(conn, 302) =~ Routes.campaign_path(conn, :edit, project.id, "mc_")

      assert 2 == Mailings.get_project_campaigns(project.id) |> Enum.count()
    end
  end
end
