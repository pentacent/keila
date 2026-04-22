defmodule Keila.Mailings.SchedulerTest do
  use Keila.DataCase, async: false
  use Oban.Testing, repo: Keila.Repo

  alias Keila.Mailings
  alias Keila.Mailings.{Scheduler, Message}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))

    sender =
      insert!(:mailings_sender,
        project_id: project.id,
        config: %Mailings.Sender.Config{type: "test"}
      )

    %{project: project, sender: sender}
  end

  defp start_scheduler!() do
    {:ok, scheduler} = Scheduler.start_link(name: nil)
    Ecto.Adapters.SQL.Sandbox.allow(Keila.Repo, self(), scheduler)

    on_exit(fn ->
      if Process.alive?(scheduler) do
        Process.exit(scheduler, :kill)
      end
    end)

    scheduler
  end

  defp insert_ready_message!(attrs) do
    insert!(:message, Map.merge(%{status: :ready, recipient_email: "test@example.com"}, attrs))
  end

  defp insert_queued_message!(attrs) do
    insert!(:message, Map.merge(%{status: :queued, recipient_email: "test@example.com"}, attrs))
  end

  describe "schedule/1" do
    @describetag :scheduler

    test "schedules ready messages for delivery", %{project: project, sender: sender} do
      for _ <- 1..5 do
        insert_ready_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "Test",
          html_body: "<p>Hello</p>",
          text_body: "Hello"
        })
      end

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      queued = Repo.all(from m in Message, where: m.status == :queued)
      assert length(queued) == 5

      assert_enqueued(worker: Mailings.DeliveryWorker)
    end

    test "does not schedule messages without a sender", %{project: project, sender: sender} do
      insert_ready_message!(%{
        project_id: project.id,
        sender_id: sender.id,
        subject: "With sender",
        html_body: "<p>Hello</p>",
        text_body: "Hello"
      })

      insert_ready_message!(%{
        project_id: project.id,
        sender_id: nil,
        subject: "Without sender",
        html_body: "<p>Hello</p>",
        text_body: "Hello"
      })

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      queued = Repo.all(from m in Message, where: m.status == :queued)
      assert length(queued) == 1
      assert hd(queued).subject == "With sender"
    end

    test "respects sender rate limits", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Mailings.Sender.Config{
            type: "test",
            rate_limit_per_second: 3
          }
        )

      for i <- 1..10 do
        insert_ready_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "Message #{i}",
          html_body: "<p>Hello</p>",
          text_body: "Hello"
        })
      end

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      queued = Repo.all(from m in Message, where: m.status == :queued)
      ready = Repo.all(from m in Message, where: m.status == :ready)

      assert length(queued) == 3
      assert length(ready) == 7
    end

    test "prioritizes higher priority messages", %{project: project} do
      # Use a rate limit of 1 per second so only one message is scheduled
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Mailings.Sender.Config{type: "test", rate_limit_per_second: 1}
        )

      low =
        insert_ready_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "Low priority",
          priority: 0,
          html_body: "<p>Low</p>",
          text_body: "Low"
        })

      high =
        insert_ready_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "High priority",
          priority: 10,
          html_body: "<p>High</p>",
          text_body: "High"
        })

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      queued = Repo.all(from m in Message, where: m.status == :queued)
      assert length(queued) == 1
      assert hd(queued).id == high.id

      still_ready = Repo.all(from m in Message, where: m.status == :ready)
      assert length(still_ready) == 1
      assert hd(still_ready).id == low.id
    end

    test "skips senders that have too many queued messages", %{project: project} do
      sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Mailings.Sender.Config{type: "test", rate_limit_per_second: 5}
        )

      for _ <- 1..5 do
        insert_queued_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "Already queued",
          text_body: "Queued"
        })
      end

      # Insert ready messages that should NOT be scheduled
      for _ <- 1..3 do
        insert_ready_message!(%{
          project_id: project.id,
          sender_id: sender.id,
          subject: "Should stay ready",
          text_body: "Hello"
        })
      end

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      ready = Repo.all(from m in Message, where: m.status == :ready)
      assert length(ready) == 3

      queued = Repo.all(from m in Message, where: m.status == :queued)
      assert length(queued) == 5
    end

    test "other senders are not affected by one sender's queued limit", %{project: project} do
      blocked_sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Mailings.Sender.Config{type: "test", rate_limit_per_second: 5}
        )

      other_sender =
        insert!(:mailings_sender,
          project_id: project.id,
          config: %Mailings.Sender.Config{type: "test"}
        )

      # Block the first sender
      for _ <- 1..5 do
        insert_queued_message!(%{
          project_id: project.id,
          sender_id: blocked_sender.id,
          subject: "Blocked queued",
          html_body: "<p>Queued</p>",
          text_body: "Queued"
        })
      end

      insert_ready_message!(%{
        project_id: project.id,
        sender_id: blocked_sender.id,
        subject: "Blocked ready",
        html_body: "<p>Blocked</p>",
        text_body: "Blocked"
      })

      # Other sender should still work
      insert_ready_message!(%{
        project_id: project.id,
        sender_id: other_sender.id,
        subject: "Other sender",
        html_body: "<p>Other</p>",
        text_body: "Other"
      })

      scheduler = start_scheduler!()
      Scheduler.schedule(scheduler)

      # Blocked sender's ready message stays ready
      blocked_ready =
        Repo.all(
          from m in Message,
            where: m.sender_id == ^blocked_sender.id and m.status == :ready
        )

      assert length(blocked_ready) == 1

      # Other sender's message was scheduled
      other_queued =
        Repo.all(
          from m in Message,
            where: m.sender_id == ^other_sender.id and m.status == :queued
        )

      assert length(other_queued) == 1
    end
  end
end
