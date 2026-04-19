defmodule Keila.Mailings.MessagePruner do
  @moduledoc """
  Oban cron worker that periodically executes the `Mailings.prune_messages/1` function.
  """

  use Oban.Worker,
    queue: :system,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing]
    ]

  alias Keila.Mailings

  @impl true
  def perform(_job) do
    Mailings.prune_messages()
  end
end
