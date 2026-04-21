defmodule Keila.Mailings.MessagePrunerTest do
  use Keila.DataCase, async: true
  import Ecto.Query

  alias Keila.Mailings.Message
  alias Keila.Mailings.MessagePruner

  setup do
    threshold =
      Application.get_env(:keila, Keila.Mailings) |> Keyword.fetch!(:message_retention_days)

    %{threshold: threshold}
  end

  test "prunes bodies from :sent and :failed messages older than threshold", %{
    threshold: threshold
  } do
    sent =
      insert!(:message,
        status: :sent,
        html_body: "sent",
        text_body: "sent",
        inserted_at: days_ago(threshold + 1)
      )

    failed =
      insert!(:message,
        status: :failed,
        html_body: "failed",
        text_body: "failed",
        inserted_at: days_ago(threshold + 1)
      )

    MessagePruner.perform(%Oban.Job{})

    sent = Repo.reload(sent)
    assert is_nil(sent.html_body)
    assert is_nil(sent.text_body)

    failed = Repo.reload(failed)
    assert is_nil(failed.html_body)
    assert is_nil(failed.text_body)
  end

  test "preserves recent messages", %{threshold: threshold} do
    recent =
      insert!(:message, status: :sent, html_body: "recent", inserted_at: days_ago(threshold - 1))

    MessagePruner.perform(%Oban.Job{})
    recent = Repo.reload(recent)
    assert recent.html_body == "recent"
  end

  test "does not touch :ready or :queued messages regardless of age", %{threshold: threshold} do
    ready =
      insert!(:message, status: :ready, html_body: "ready", inserted_at: days_ago(threshold + 5))

    queued =
      insert!(:message,
        status: :queued,
        html_body: "queued",
        inserted_at: days_ago(threshold + 5)
      )

    MessagePruner.perform(%Oban.Job{})
    assert Repo.reload(ready).html_body == "ready"
    assert Repo.reload(queued).html_body == "queued"
  end

  test "prunes messages in batches and re-enqueues itself", %{threshold: threshold} do
    batch_size = MessagePruner.batch_size()

    insert_n!(:message, batch_size + 1, fn _n ->
      [status: :sent, html_body: "sent", text_body: "sent", inserted_at: days_ago(threshold + 1)]
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
