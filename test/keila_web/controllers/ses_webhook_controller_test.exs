defmodule KeilaWeb.SESWebhookControllerTest do
  use KeilaWeb.ConnCase, async: false

  @message_id "0107017b35af3acd-6de953a5-17a7-4301-8f17-40e8fbacbbc1-000000"

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :ses_webhook_controller
  test "handle bounces from SES", %{conn: conn, project: project} do
    contact = insert!(:contact, status: :active, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    recipient =
      insert!(:mailings_recipient,
        contact_id: contact.id,
        campaign_id: campaign.id,
        receipt: @message_id
      )

    data = File.read!("test/keila/mailings/ses/bounce.signed.json")

    conn =
      conn
      |> put_req_header("content-type", "text/plain; charset=UTF-8")
      |> post(Routes.ses_webhook_path(conn, :webhook), data)

    assert 200 == conn.status

    assert %{status: :unreachable} = Keila.Repo.get(Keila.Contacts.Contact, recipient.contact_id)
  end

  @tag :ses_webhook_controller
  @tag :skip
  # This test is not suitable for running as part of the test suite but
  # is part of this file to document how the SNS Subscription feature can be
  # tested
  test "subscription_created webhook", %{conn: conn, project: project} do
    data = File.read!("test/keila/mailings/ses/subscription.signed.json")

    conn =
      conn
      |> put_req_header("content-type", "text/plain; charset=UTF-8")
      |> post(Routes.ses_webhook_path(conn, :webhook), data)

    assert 200 == conn.status
  end
end
