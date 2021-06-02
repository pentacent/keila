defmodule Keila.Mailings.SenderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.Sender

  @tag :mailings
  describe "Creating senders" do
    @tag :mailings
    test "through the API" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      {:ok, %Sender{}} = Mailings.create_sender(project.id, params(:mailings_sender))
    end

    @tag :mailingsx
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
    @tag :mailings
    test "is idempotent" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      assert :ok == Mailings.delete_sender(sender.id)
      assert :ok == Mailings.delete_sender(sender.id)
    end

    @tag :mailings
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

  @tag :mailings
  describe "Update senders" do
    @tag :mailings
    test "through the API" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      config_params = %{"id" => sender.config.id, "type" => "test", "test_string" => "callback-success"}
      params = %{"name" => "Updated name", "config" => config_params}
      assert {:ok, %{name: "Updated name"}} = Mailings.update_sender(sender.id, params)
    end

    @tag :mailings
    test "fails when there is a callback error" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)

      config_params = %{"id" => sender.config.id, "type" => "test", "test_string" => "callback-fail"}
      params = %{"name" => "Updated name", "config" => config_params}
      assert {:error, _changeset} = Mailings.update_sender(sender.id, params)
    end
  end
end
