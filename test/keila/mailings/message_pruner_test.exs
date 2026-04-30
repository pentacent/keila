defmodule Keila.Mailings.MessagePrunerTest do
  use Keila.DataCase, async: true
  import Ecto.Query

  alias Keila.Mailings.Message
  alias Keila.Mailings.MessagePruner

  setup do
    threshold =
      Application.get_env(:keila, Keila.Mailings) |> Keyword.fetch!(:message_retention_days)

    group = insert!(:group)
    project = insert!(:project, group: group)

    %{threshold: threshold, project: project}
  end

  test "prunes bodies from :sent and :failed messages older than threshold", %{
    threshold: threshold,
    project: project
  } do
    sent =
      insert!(:message,
        project: project,
        status: :sent,
        html_body: "sent",
        text_body: "sent",
        updated_at: days_ago(threshold + 1)
      )

    failed =
      insert!(:message,
        project: project,
        status: :failed,
        html_body: "failed",
        text_body: "failed",
        updated_at: days_ago(threshold + 1)
      )

    MessagePruner.perform(%Oban.Job{})

    sent = Repo.reload(sent)
    assert is_nil(sent.html_body)
    assert is_nil(sent.text_body)

    failed = Repo.reload(failed)
    assert is_nil(failed.html_body)
    assert is_nil(failed.text_body)
  end

  test "preserves recent messages", %{threshold: threshold, project: project} do
    recent =
      insert!(:message,
        project: project,
        status: :sent,
        html_body: "recent",
        updated_at: days_ago(threshold - 1)
      )

    MessagePruner.perform(%Oban.Job{})
    recent = Repo.reload(recent)
    assert recent.html_body == "recent"
  end

  test "does not touch :ready or :queued messages regardless of age", %{
    threshold: threshold,
    project: project
  } do
    ready =
      insert!(:message,
        project: project,
        status: :ready,
        html_body: "ready",
        updated_at: days_ago(threshold + 5),
        project: project
      )

    queued =
      insert!(:message,
        project: project,
        status: :queued,
        html_body: "queued",
        updated_at: days_ago(threshold + 5)
      )

    MessagePruner.perform(%Oban.Job{})
    assert Repo.reload(ready).html_body == "ready"
    assert Repo.reload(queued).html_body == "queued"
  end

  test "prunes messages in batches and re-enqueues itself", %{
    threshold: threshold,
    project: project
  } do
    batch_size = MessagePruner.batch_size()

    insert_n!(:message, batch_size + 1, fn _n ->
      [
        project: project,
        status: :sent,
        html_body: "sent",
        text_body: "sent",
        updated_at: days_ago(threshold + 1)
      ]
    end)

    MessagePruner.perform(%Oban.Job{})

    assert from(m in Message, where: is_nil(m.text_body)) |> Repo.aggregate(:count, :id) ==
             batch_size

    assert %{success: 1} = Oban.drain_queue(queue: :system)

    assert from(m in Message, where: is_nil(m.text_body)) |> Repo.aggregate(:count, :id) ==
             batch_size + 1

    assert %{success: 0} = Oban.drain_queue(queue: :system)
  end

  defp days_ago(n) do
    DateTime.utc_now(:second) |> DateTime.add(-n, :day)
  end
end
