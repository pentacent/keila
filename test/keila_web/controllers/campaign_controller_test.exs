defmodule KeilaWeb.CampaignControllerTest do
  use KeilaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Keila.Mailings
  @endpoint KeilaWeb.Endpoint

  describe "GET /projects/:p_id/campaigns" do
    @tag :campaign_controller
    test "list campaigns", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      campaigns = insert_n!(:mailings_campaign, 5, fn _ -> %{project_id: project.id} end)
      conn = get(conn, Routes.campaign_path(conn, :index, project.id))
      assert html_response = html_response(conn, 200)
      for campaign <- campaigns, do: assert(html_response =~ campaign.subject)
    end

    @tag :campaign_controller
    test "show empty state", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.campaign_path(conn, :index, project.id))
      assert html_response(conn, 200) =~ "Create your first campaign"
    end
  end

  describe "GET /projects/:p_id/campaigns/new" do
    @tag :campaign_controller
    test "shows creation page with subject form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      conn = get(conn, Routes.campaign_path(conn, :new, project.id))
      assert html_response(conn, 200) =~ ~r{New Campaign\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/campaigns/new" do
    @tag :campaign_controller
    test "creates new campaign and redirects", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      params = %{"subject" => "My Campaign", "settings" => %{"type" => "text"}}
      conn = post(conn, Routes.campaign_path(conn, :post_new, project.id, campaign: params))
      assert redirected_to(conn, 302) =~ Routes.campaign_path(conn, :edit, project.id, "nmc_")
    end

    @tag :campaign_controller
    test "validates params", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      params = %{"subject" => "", "settings" => %{"type" => "text"}}
      conn = post(conn, Routes.campaign_path(conn, :post_new, project.id, campaign: params))
      assert html_response(conn, 400) =~ ~r{can&#39;t be blank}
    end
  end

  describe "LV /projects/:p_id/campaigns/:id" do
    @tag :campaign_controller
    test "shows edit form", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))

      assert html_response(conn, 200) =~ ~r{Edit Campaign\s*</h1>}
    end

    @tag :campaign_controller
    test "generates campaign preview", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      campaign =
        insert!(:mailings_campaign,
          project_id: project.id,
          text_body: "Hello there!",
          settings: %{type: :text}
        )

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

    @tag :campaign_controller
    test "updates campaign and redirects to index", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      sender = build(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender: sender)

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, _html} = live(conn)

      lv
      |> element("#campaign")
      |> render_submit(%{campaign: %{subject: "Foo Bar"}})

      assert_redirect(lv, Routes.campaign_path(conn, :index, project.id), 5)
      assert %{subject: "Foo Bar"} = Mailings.get_campaign(campaign.id)
    end

    @tag :campaign_controller
    test "delivers campaign and redirects to stats page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      sender = build(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender: sender)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, _html} = live(conn)

      lv
      |> element("[data-dialog-for=\"send\"] .button--cta")
      |> render_click()

      assert_redirect(lv, Routes.campaign_path(conn, :stats, project.id, campaign.id), 5)

      # Avoid database pool error when exiting test before transaction has
      # finished
      :timer.sleep(500)
      assert %{sent_at: %DateTime{}} = Mailings.get_campaign(campaign.id)
    end

    @tag :campaign_controller
    test "schedules a campaign and redirects to index", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      sender = build(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender: sender)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, _html} = live(conn)

      params = %{
        "schedule" => %{
          "schedule" => "true",
          "date" => "9999-12-31",
          "time" => "12:00",
          "timezone" => "Etc/UTC"
        }
      }

      lv
      |> element("[data-dialog-for=\"schedule\"] form")
      |> render_submit(params)

      assert_redirect(lv, Routes.campaign_path(conn, :index, project.id), 5)

      updated_campaign = Mailings.get_campaign(campaign.id)
      assert updated_campaign.scheduled_for
    end

    @tag :campaign_controller
    test "unschedules a campaign and redirects to index", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      sender = build(:mailings_sender, project_id: project.id)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      {:ok, scheduled_for, _} = DateTime.from_iso8601("9999-12-31 12:00:00Z")

      campaign =
        insert!(:mailings_campaign,
          project_id: project.id,
          sender: sender,
          scheduled_for: scheduled_for
        )

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, _html} = live(conn)

      lv
      |> element("#unschedule-button")
      |> render_click()

      assert_redirect(lv, Routes.campaign_path(conn, :index, project.id), 5)

      updated_campaign = Mailings.get_campaign(campaign.id)
      refute updated_campaign.scheduled_for
    end

    @tag :campaign_controller
    test "displays error when trying to send without sender", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      campaign_no_sender = insert!(:mailings_campaign, project_id: project.id)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      # Sending with no sender
      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign_no_sender.id))
      {:ok, lv, _html} = live(conn)

      assert lv
             |> element("[data-dialog-for=\"send\"] .button--cta")
             |> render_click() =~ "You must specify a sender before sending/scheduling a campaign"
    end

    @tag :campaign_controller
    test "displays error when trying to schedule without sender", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      campaign_no_sender = insert!(:mailings_campaign, project_id: project.id)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign_no_sender.id))
      {:ok, lv, _html} = live(conn)

      params = %{
        "schedule" => %{
          "schedule" => "true",
          "date" => "9999-12-31",
          "time" => "12:00",
          "timezone" => "Etc/UTC"
        }
      }

      lv
      |> element("[data-dialog-for=\"schedule\"] form")
      |> render_submit(params) =~ "You must specify a sender before sending/scheduling a campaign"
    end

    @tag :campaign_controller
    test "displays error when trying to schedule with a time before the threshold", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      sender = build(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender: sender)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, campaign.id))
      {:ok, lv, _html} = live(conn)

      params = %{
        "schedule" => %{
          "schedule" => "true",
          "date" => "1970-01-01",
          "time" => "12:00",
          "timezone" => "Etc/UTC"
        }
      }

      lv
      |> element("[data-dialog-for=\"schedule\"] form")
      |> render_submit(params) =~ "There was an error scheduling your campaign"
    end

    @tag :campaign_controller
    test "displays error when trying to schedule a campaign that's already scheduled for a time before the threshold",
         %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      sender = build(:mailings_sender, project_id: project.id)
      _contacts = insert_n!(:contact, 10, fn _ -> %{project_id: project.id} end)

      {:ok, scheduled_for, _} = DateTime.from_iso8601("1970-01-01 12:00:00Z")

      scheduled_campaign =
        insert!(:mailings_campaign,
          project_id: project.id,
          sender: sender,
          scheduled_for: scheduled_for
        )

      conn = get(conn, Routes.campaign_path(conn, :edit, project.id, scheduled_campaign.id))
      {:ok, lv, _html} = live(conn)

      params = %{
        "schedule" => %{
          "schedule" => "true",
          "date" => "9999-12-31",
          "time" => "12:00",
          "timezone" => "Etc/UTC"
        }
      }

      lv
      |> element("[data-dialog-for=\"schedule\"] form")
      |> render_submit(params) =~ "There was an error scheduling your campaign"
    end
  end

  describe "LV /projects/:p_id/campaigns/:id/stats" do
    @tag :campaign_controller
    test "shows delivery progress and success message", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

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

      Oban.drain_queue(queue: :periodic)
      Oban.drain_queue(queue: :mailer, with_scheduled: true)
      :timer.sleep(1500)

      assert render(lv) =~
               "<div class=\"text-sm\">emails sent</div><div class=\"text-3xl\">10</div>"
    end
  end

  describe "DELETE /projects/" do
    @tag :campaign_controller
    test "deletes campaign", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
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
      {conn, project} = with_login_and_project(conn)
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
      {conn, project} = with_login_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      conn = get(conn, Routes.campaign_path(conn, :clone, project.id, campaign.id))
      assert html_response(conn, 200) =~ ~r{Clone Campaign\s*</h1>}
    end
  end

  describe "POST /projects/:p_id/campaigns/:id/clone" do
    @tag :campaign_controller
    test "clones campaign and redirects to edit page", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      campaign = insert!(:mailings_campaign, project_id: project.id)
      params = %{"subject" => "Foo bar"}

      conn =
        post(conn, Routes.campaign_path(conn, :clone, project.id, campaign.id, campaign: params))

      assert redirected_to(conn, 302) =~ Routes.campaign_path(conn, :edit, project.id, "nmc_")

      assert 2 == Mailings.get_project_campaigns(project.id) |> Enum.count()
    end
  end
end
