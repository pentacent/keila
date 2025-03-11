defmodule KeilaWeb.ApiCampaignControllerTest do
  use KeilaWeb.ApiCase

  describe "GET /api/v1/campaigns" do
    @tag :api_campaign_controller
    test "lists campaigns", %{authorized_conn: conn, project: project} do
      n = 10
      insert_n!(:mailings_campaign, n, fn _n -> %{project_id: project.id} end)

      conn = get(conn, Routes.api_campaign_path(conn, :index))

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert Enum.count(campaigns) == n
    end
  end

  describe "POST /api/v1/campaigns" do
    @tag :api_campaign_controller
    test "creates new campaign", %{authorized_conn: conn, project: project} do
      %{id: sender_id} = insert!(:mailings_sender, project_id: project.id)
      %{id: segment_id} = insert!(:contacts_segment, project_id: project.id)

      body = %{
        "data" => %{
          "subject" => "Test Subject",
          "text_body" => "Lorem Ipsum",
          "sender_id" => sender_id,
          "segment_id" => segment_id,
          "settings" => %{
            "type" => "markdown"
          }
        }
      }

      conn = post_json(conn, Routes.api_campaign_path(conn, :create), body)

      assert %{
               "data" => %{
                 "subject" => "Test Subject",
                 "text_body" => "Lorem Ipsum",
                 "sender_id" => ^sender_id,
                 "segment_id" => ^segment_id,
                 "settings" => %{"type" => "markdown"}
               }
             } = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/campaigns/:id" do
    @tag :api_campaign_controller
    test "retrieves existing campaign", %{authorized_conn: conn, project: project} do
      %{id: id, subject: subject, text_body: text_body} =
        insert!(:mailings_campaign, project_id: project.id)

      conn = get(conn, Routes.api_campaign_path(conn, :show, id))

      assert %{
               "data" => %{
                 "id" => ^id,
                 "subject" => ^subject,
                 "text_body" => ^text_body
               }
             } = json_response(conn, 200)
    end
  end

  describe "PATCH /api/v1/campaigns/:id" do
    @tag :api_campaign_controller
    test "updates existing campaign", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:mailings_campaign, project_id: project.id)

      body = %{"data" => %{"subject" => "Updated Subject", "settings" => %{"type" => "markdown"}}}
      conn = patch_json(conn, Routes.api_campaign_path(conn, :update, id), body)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "subject" => "Updated Subject",
                 "settings" => %{
                   "type" => "markdown"
                 }
               }
             } = json_response(conn, 200)

      assert %{subject: "Updated Subject"} = Keila.Mailings.get_campaign(id)
    end

    @tag :api_campaign_controller
    test "also works when settings are not provided", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:mailings_campaign, project_id: project.id, settings: %{type: "mjml"})

      body = %{"data" => %{"subject" => "Updated Subject"}}
      conn = patch_json(conn, Routes.api_campaign_path(conn, :update, id), body)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "subject" => "Updated Subject",
                 "settings" => %{
                   "type" => "mjml"
                 }
               }
             } = json_response(conn, 200)

      assert %{subject: "Updated Subject"} = Keila.Mailings.get_campaign(id)
    end
  end

  describe "DELETE /api/v1/campaigns/:id" do
    @tag :api_campaign_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:mailings_campaign, project_id: project.id)

      conn = delete(conn, Routes.api_campaign_path(conn, :delete, id))

      assert nil == Keila.Mailings.get_campaign(id)

      conn = delete(conn, Routes.api_campaign_path(conn, :delete, id))
      assert conn.status == 204
    end
  end

  describe "POST /api/v1/campaigns/:id/actions/send" do
    @tag :api_campaign_controller
    test "returns 202", %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)
      %{id: id} = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)
      insert_n!(:contact, 50, fn _n -> %{project_id: project.id} end)

      conn = post(conn, Routes.api_campaign_path(conn, :deliver, id))

      assert %{
               "delivery_queued" => true,
               "campaign_id" => ^id
             } = json_response(conn, 202)["data"]

      :timer.sleep(500)
      campaign = Keila.Mailings.get_campaign(id)
      assert not is_nil(campaign.sent_at)
    end
  end

  describe "POST /api/v1/campaigns/:id/actions/schedule" do
    @tag :api_campaign_controller
    test "returns updated campaign", %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)
      %{id: id} = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)
      insert_n!(:contact, 50, fn _n -> %{project_id: project.id} end)

      scheduled_for =
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(60 * 60, :second)

      body = %{
        "data" => %{
          "scheduled_for" => scheduled_for |> DateTime.to_iso8601()
        }
      }

      conn = post_json(conn, Routes.api_campaign_path(conn, :schedule, id), body)

      assert json_response(conn, 200)

      assert %{scheduled_for: ^scheduled_for} = Keila.Mailings.get_campaign(id)
    end
  end
end
