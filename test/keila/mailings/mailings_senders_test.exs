defmodule Keila.Mailings.SenderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.Sender

  # Structurally valid but incorrect credentials
  @smtp_params %{
    "name" => "Sender",
    "from_email" => "user@example.com",
    "config" => %{
      "type" => "smtp",
      "smtp_username" => "user",
      "smtp_password" => "password",
      "smtp_relay" => "mail.example.com"
    }
  }

  # Correct credentials
  @test_params %{
    "name" => "Sender 2",
    "from_email" => "user2@example.com",
    "config" => %{
      "type" => "test"
    }
  }

  @tag :mailings
  test "Create senders" do
    group = insert!(:group)
    project = insert!(:project, group: group)

    {:ok, %Sender{}} = Mailings.create_sender(project.id, @smtp_params)
  end

  test "Delete senders" do
  end

  test "Update senders" do
  end

  @tag :mailings
  test "Try credentials" do
    group = insert!(:group)
    project = insert!(:project, group: group)

    {:ok, %Sender{id: sender_id}} = Mailings.create_sender(project.id, @smtp_params)
    assert {:error, _} = Mailings.try_credentials(sender_id)

    {:ok, %Sender{id: sender_id}} = Mailings.create_sender(project.id, @test_params)
    assert {:ok, _} = Mailings.try_credentials(sender_id)
  end
end
