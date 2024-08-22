defmodule Keila.Mailings.SenderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.Sender
  alias Mailings.RateLimiter

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
      assert nil == Mailings.get_sender(sender.id)
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

  describe "Update senders" do
    @tag :mailings
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

    @tag :mailings
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

  describe "Verify senders" do
    @tag :mailings
    test "through the API" do
      group = insert!(:group)
      project = insert!(:project, group: group)
      sender = insert!(:mailings_sender, project: project)
      token = Keila.TestSenderAdapter.get_verification_token(sender)

      assert {:ok, %Sender{config: %{test_verified_at: verified_at}}} =
               Mailings.verify_sender_from_token(token)

      assert not is_nil(verified_at)
    end

    @tag :mailings
    test "fails when there is a callback error" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      sender =
        insert!(:mailings_sender, project: project, config: %{test_string: "callback-fail"})

      token = Keila.TestSenderAdapter.get_verification_token(sender)

      assert {:error, _term} = Mailings.verify_sender_from_token(token)
    end
  end

  describe "Testing senders with Rate Limiting" do
    test "using check rate limit by seconds of new sender" do
      rate_limit_per_second = 50
      group = insert!(:group)
      project = insert!(:project, group: group)

      params =
        params(:mailings_sender)
        |> Map.update!("config", fn config ->
          Map.put(config, :rate_limit_per_second, rate_limit_per_second)
        end)

      {:ok, sender} =
        Mailings.create_sender(
          project.id,
          params
        )

      assert rate_limit_per_second == sender.config.rate_limit_per_second

      for _ <- 1..rate_limit_per_second do
        assert :ok = RateLimiter.check_sender_rate_limit(sender)
      end

      assert {:error, {_schedule_at, _}} = RateLimiter.check_sender_rate_limit(sender)
    end

    test "using check rate limit by minutes of new sender" do
      rate_limit_per_minute = 50
      group = insert!(:group)
      project = insert!(:project, group: group)

      params =
        params(:mailings_sender)
        |> Map.update!("config", fn config ->
          Map.put(config, :rate_limit_per_minute, rate_limit_per_minute)
        end)

      {:ok, sender} =
        Mailings.create_sender(
          project.id,
          params
        )

      assert rate_limit_per_minute == sender.config.rate_limit_per_minute

      for _ <- 1..rate_limit_per_minute do
        assert :ok = RateLimiter.check_sender_rate_limit(sender)
      end

      assert {:error, {_schedule_at, _}} = RateLimiter.check_sender_rate_limit(sender)
    end

    test "using check rate limit by hours of new sender" do
      rate_limit_per_hour = 50
      group = insert!(:group)
      project = insert!(:project, group: group)

      params =
        params(:mailings_sender)
        |> Map.update!("config", fn config ->
          Map.put(config, :rate_limit_per_hour, rate_limit_per_hour)
        end)

      {:ok, sender} =
        Mailings.create_sender(
          project.id,
          params
        )

      assert rate_limit_per_hour == sender.config.rate_limit_per_hour

      for _ <- 1..rate_limit_per_hour do
        assert :ok = RateLimiter.check_sender_rate_limit(sender)
      end

      assert {:error, {_schedule_at, _}} = RateLimiter.check_sender_rate_limit(sender)
    end

    test "using check rate without limit of new sender" do
      group = insert!(:group)
      project = insert!(:project, group: group)

      {:ok, sender} = Mailings.create_sender(project.id, params(:mailings_sender))

      assert sender.config.rate_limit_per_second == nil
      assert sender.config.rate_limit_per_minute == nil
      assert sender.config.rate_limit_per_hour == nil

      for _ <- 1..50 do
        assert :ok = RateLimiter.check_sender_rate_limit(sender)
      end
    end
  end
end
