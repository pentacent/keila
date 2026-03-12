defmodule Keila.Mailings.SenderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.Sender

  describe "Creating senders" do
    @describetag :mailings
    test "through the API" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      {:ok, %Sender{}} = Mailings.create_sender(project.id, params(:mailings_sender))
    end

    test "fails when there is a callback error" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      params =
        params(:mailings_sender)
        |> Map.put("config", %{type: "test", test_string: "callback-fail"})

      assert {:error, %Ecto.Changeset{}} = Mailings.create_sender(project.id, params)

      assert [] == Mailings.get_project_senders(project.id)
    end
  end

  describe "Deleting senders" do
    @describetag :mailings
    test "is idempotent" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      assert :ok == Mailings.delete_sender(sender.id)
      assert nil == Mailings.get_sender(sender.id)
      assert :ok == Mailings.delete_sender(sender.id)
    end

    test "fails when there is a callback error" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      %{id: id} =
        insert!(:mailings_sender,
          project: project,
          config: %{type: "test", test_string: "callback-fail"}
        )

      sender = Mailings.get_sender(id)

      assert {:error, _} = Mailings.delete_sender(sender.id)
      assert sender == Mailings.get_sender(sender.id)
    end
  end

  describe "Update senders" do
    @describetag :mailings
    test "through the API" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      config_params = %{
        "id" => sender.config.id,
        "type" => "test",
        "test_string" => "callback-success"
      }

      params = %{"name" => "Updated name", "config" => config_params}
      assert {:ok, %{name: "Updated name"}} = Mailings.update_sender(sender.id, params)
    end

    test "fails when there is a callback error" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      config_params = %{
        "id" => sender.config.id,
        "type" => "test",
        "test_string" => "callback-fail"
      }

      params = %{"name" => "Updated name", "config" => config_params}
      assert {:error, _changeset} = Mailings.update_sender(sender.id, params)
    end
  end

  describe "Sender from_email verification" do
    @describetag :mailings
    test "send_sender_verification_email creates token and sends email" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)
      from_email = sender.from_email

      {:ok, agent_pid} = Agent.start_link(fn -> nil end)
      capture_token = capture_and_return_token(agent_pid)
      Keila.Mailings.send_sender_verification_email(sender.id, &capture_token.(&1))
      token = Agent.get(agent_pid, & &1)

      {:email, %{text_body: text_body}} = assert_email_sent()
      assert String.contains?(text_body, token)

      assert {:ok, %Sender{verified_from_email: ^from_email}} =
               Mailings.verify_sender_from_email(token)
    end

    test "verify_sender_from_email fails with invalid token" do
      assert :error == Mailings.verify_sender_from_email("invalid-token")
    end

    test "cancel_sender_from_email_verification deletes token and returns :ok" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      # Create a token
      {:ok, agent_pid} = Agent.start_link(fn -> nil end)
      capture_token = capture_and_return_token(agent_pid)
      Keila.Mailings.send_sender_verification_email(sender.id, &capture_token.(&1))
      token = Agent.get(agent_pid, & &1)

      # Cancel the token
      assert :ok == Mailings.cancel_sender_from_email_verification(token)

      # Verify token is deleted - verification should fail
      assert :error == Mailings.verify_sender_from_email(token)
    end

    test "cancel_sender_from_email_verification returns :ok for non-existent token" do
      assert :ok == Mailings.cancel_sender_from_email_verification("non-existent-token")
    end
  end

  defp capture_and_return_token(agent_pid) do
    fn token ->
      :ok = Agent.update(agent_pid, fn _ -> token end)
      token
    end
  end
end
