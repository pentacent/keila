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

  @batch_size 10000

  @impl true
  def perform(_job) do
    case Mailings.prune_messages(@batch_size) do
      {@batch_size, _} ->
        Oban.insert!(new(%{}))

      _other ->
        :ok
    end
  end

  @doc """
  Returns the batch size used by the worker.
  """
  def batch_size(), do: @batch_size
end
