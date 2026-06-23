defmodule KeilaWeb.ApiMessageControllerTest do
  use KeilaWeb.ApiCase
  require Keila

  alias Keila.Mailings.Message

  describe "POST /api/v1/messages" do
    @tag :api_message_controller
    test "requires auth", %{conn: conn} do
      conn =
        post_json(conn, Routes.api_message_path(conn, :create), %{
          "data" => %{"type" => "text", "recipient_email" => "to@example.com"}
        })

      assert %{"errors" => [%{"status" => "403"}]} = json_response(conn, 403)
    end

    @tag :api_message_controller
    test "creates a message with text content and persists it with :ready state",
         %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)

      Keila.if_cloud do
        account = Keila.Accounts.get_project_account(project.id)
        KeilaCloud.Accounts.update_account_status(account.id, :active)
      end

      params = %{
        "data" => %{
          "type" => "text",
          "sender_id" => sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hello",
          "text_body" => "Hi"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :create), params)

      assert %{
               "data" => %{
                 "id" => message_id,
                 "recipient_email" => "to@example.com",
                 "subject" => "Hello"
               }
             } = json_response(conn, 200)

      assert %Message{status: :ready} = Keila.Repo.get(Message, message_id)
    end

    @tag :api_message_controller
    test "accepts cc/bcc as a JSON array of addresses",
         %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)

      Keila.if_cloud do
        account = Keila.Accounts.get_project_account(project.id)
        KeilaCloud.Accounts.update_account_status(account.id, :active)
      end

      params = %{
        "data" => %{
          "type" => "text",
          "sender_id" => sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hello",
          "text_body" => "Hi",
          "cc" => ["lois@example.com", "stewie@example.com"],
          "bcc" => ["brian@example.com"]
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :create), params)

      assert %{"data" => %{"id" => message_id}} = json_response(conn, 200)

      assert %Message{
               cc: ["lois@example.com", "stewie@example.com"],
               bcc: ["brian@example.com"]
             } = Keila.Repo.get(Message, message_id)
    end

    @tag :api_message_controller
    test "returns 400 for missing required fields",
         %{authorized_conn: conn} do
      conn =
        post_json(conn, Routes.api_message_path(conn, :create), %{
          "data" => %{"recipient_email" => "to@example.com"}
        })

      assert %{"errors" => [%{"status" => "400"} | _]} = json_response(conn, 400)
    end

    @tag :api_message_controller
    test "returns 404 when sender belongs to another project",
         %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      other_sender = insert!(:mailings_sender, project_id: other_project.id)

      params = %{
        "data" => %{
          "type" => "text",
          "sender_id" => other_sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hi",
          "text_body" => "Hi"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :create), params)
      assert %{"errors" => [%{"status" => "404"}]} = json_response(conn, 404)
    end

    @tag :api_message_controller
    test "returns 400 when no body source is provided",
         %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)

      params = %{
        "data" => %{
          "type" => "text",
          "sender_id" => sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hi"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :create), params)

      assert %{"errors" => [%{"status" => "400"} | _]} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/messages/actions/render" do
    @tag :api_message_controller
    test "renders the message and returns the output without persisting anything",
         %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)

      params = %{
        "data" => %{
          "type" => "html",
          "sender_id" => sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hello {{ contact.email }}",
          "html_body" => "<p>Hi {{ contact.email }}</p>"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :render), params)

      assert %{
               "data" => %{
                 "subject" => "Hello to@example.com",
                 "html_body" => html_body,
                 "text_body" => text_body
               }
             } = json_response(conn, 200)

      assert html_body =~ "Hi to@example.com"
      assert text_body =~ "Hi to@example.com"

      assert is_nil(Keila.Repo.one(Message))
    end

    @tag :api_message_controller
    test "returns 400 when the message fails to render",
         %{authorized_conn: conn, project: project} do
      sender = insert!(:mailings_sender, project_id: project.id)

      params = %{
        "data" => %{
          "type" => "mjml",
          "sender_id" => sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hi",
          "mjml_body" => "<mjml><mj-body><mj-text>{{ broken </mj-text></mj-body></mjml>"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :render), params)

      assert %{"errors" => [%{"status" => "400", "detail" => detail} | _]} =
               json_response(conn, 400)

      assert is_binary(detail) and detail != ""
    end

    @tag :api_message_controller
    test "returns 404 when sender belongs to another project",
         %{authorized_conn: conn, user: user} do
      {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))
      other_sender = insert!(:mailings_sender, project_id: other_project.id)

      params = %{
        "data" => %{
          "type" => "text",
          "sender_id" => other_sender.id,
          "recipient_email" => "to@example.com",
          "subject" => "Hi",
          "text_body" => "Hi"
        }
      }

      conn = post_json(conn, Routes.api_message_path(conn, :render), params)
      assert %{"errors" => [%{"status" => "404"}]} = json_response(conn, 404)
    end
  end
end
