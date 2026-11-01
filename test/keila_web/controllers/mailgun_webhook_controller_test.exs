defmodule KeilaWeb.MailgunWebhookControllerTest do
  use KeilaWeb.ConnCase, async: true

  alias Keila.Contacts.Contact
  alias Keila.Repo

  @signing_key "f1a2b3c4d5e6f708192a3b4c5d6e7f80"
  @mailgun_id "20211018120000.1.0123456789ABCDEF@mg.example.com"

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))

    sender =
      insert!(:mailings_sender,
        project_id: project.id,
        config: %{
          type: "mailgun",
          mailgun_api_key: "key-foo",
          mailgun_domain: "mg.example.com",
          mailgun_webhook_signing_key: @signing_key
        }
      )

    contact = insert!(:contact, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    # Swoosh stores the ID returned by Mailgun enclosed in angle brackets
    message =
      insert!(:message,
        project: project,
        sender_id: sender.id,
        contact_id: contact.id,
        campaign_id: campaign.id,
        receipt: "<#{@mailgun_id}>"
      )

    %{project: project, sender: sender, contact: contact, message: message}
  end

  defp payload(event_data, opts \\ []) do
    key = Keyword.get(opts, :signing_key, @signing_key)
    timestamp = "1634558400"
    token = "b0e7a5a1d0c0f7a1d3a4f1c2e5b6d7c8a9f0e1d2c3b4a5f6e7"

    signature =
      :crypto.mac(:hmac, :sha256, key, timestamp <> token)
      |> Base.encode16(case: :lower)

    %{
      "signature" => %{"timestamp" => timestamp, "token" => token, "signature" => signature},
      "event-data" =>
        Map.merge(
          %{"message" => %{"headers" => %{"message-id" => @mailgun_id}}},
          event_data
        )
    }
  end

  defp post_webhook(conn, payload) do
    post(conn, Routes.mailgun_webhook_path(conn, :webhook), payload)
  end

  @tag :mailgun_webhook_controller
  test "permanent failure marks contact as unreachable", %{
    conn: conn,
    contact: contact,
    message: message
  } do
    conn =
      post_webhook(
        conn,
        payload(%{
          "event" => "failed",
          "severity" => "permanent",
          "reason" => "bounce",
          "delivery-status" => %{"code" => 550}
        })
      )

    assert 200 == conn.status
    assert %{status: :unreachable} = Repo.get(Contact, contact.id)
    assert Keila.Mailings.get_message(message.id).hard_bounce_received_at
  end

  @tag :mailgun_webhook_controller
  test "temporary failure is handled as soft bounce", %{
    conn: conn,
    contact: contact,
    message: message
  } do
    conn = post_webhook(conn, payload(%{"event" => "failed", "severity" => "temporary"}))

    assert 200 == conn.status
    assert %{status: :active} = Repo.get(Contact, contact.id)
    assert Keila.Mailings.get_message(message.id).soft_bounce_received_at
  end

  @tag :mailgun_webhook_controller
  test "complaint is handled", %{conn: conn, message: message} do
    conn = post_webhook(conn, payload(%{"event" => "complained"}))

    assert 200 == conn.status
    assert Keila.Mailings.get_message(message.id).complaint_received_at
  end

  @tag :mailgun_webhook_controller
  test "finds messages whose receipt was stored without angle brackets", %{
    conn: conn,
    contact: contact,
    message: message
  } do
    message |> Ecto.Changeset.change(receipt: @mailgun_id) |> Repo.update!()

    conn = post_webhook(conn, payload(%{"event" => "failed", "severity" => "permanent"}))

    assert 200 == conn.status
    assert %{status: :unreachable} = Repo.get(Contact, contact.id)
  end

  @tag :mailgun_webhook_controller
  test "ignores other events", %{conn: conn, contact: contact} do
    conn = post_webhook(conn, payload(%{"event" => "delivered"}))

    assert 204 == conn.status
    assert %{status: :active} = Repo.get(Contact, contact.id)
  end

  @tag :mailgun_webhook_controller
  test "rejects invalid signatures", %{conn: conn, contact: contact} do
    conn =
      post_webhook(
        conn,
        payload(%{"event" => "failed", "severity" => "permanent"}, signing_key: "wrong-key")
      )

    assert 403 == conn.status
    assert %{status: :active} = Repo.get(Contact, contact.id)
  end

  @tag :mailgun_webhook_controller
  test "rejects webhooks if the sender has no signing key", %{conn: conn, project: project} do
    sender =
      insert!(:mailings_sender,
        project_id: project.id,
        config: %{type: "mailgun", mailgun_api_key: "key-foo", mailgun_domain: "mg.example.com"}
      )

    contact = insert!(:contact, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id)

    insert!(:message,
      project: project,
      sender_id: sender.id,
      contact_id: contact.id,
      campaign_id: campaign.id,
      receipt: "<no-key@mg.example.com>"
    )

    conn =
      post_webhook(
        conn,
        payload(%{
          "event" => "failed",
          "severity" => "permanent",
          "message" => %{"headers" => %{"message-id" => "no-key@mg.example.com"}}
        })
      )

    assert 403 == conn.status
    assert %{status: :active} = Repo.get(Contact, contact.id)
  end

  @tag :mailgun_webhook_controller
  test "returns 406 for unknown messages", %{conn: conn} do
    payload =
      payload(%{
        "event" => "failed",
        "severity" => "permanent",
        "message" => %{"headers" => %{"message-id" => "unknown@mg.example.com"}}
      })

    conn = post_webhook(conn, payload)

    assert 406 == conn.status
  end
end
