defmodule Keila.Auth.EventPruner do
  @moduledoc """
  Oban cron worker that periodically runs the `Auth.prune_events/1` function.
  """

  use Oban.Worker,
    queue: :system,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing]
    ]

  alias Keila.Auth

  @batch_size 10000

  @impl true
  def perform(_job) do
    case Auth.prune_events(@batch_size) do
      {@batch_size, _} ->
        Oban.insert!(new(%{}, unique: false))
        :ok

      _other ->
        :ok
    end
  end

  @doc """
  Returns the batch size used by the worker.
  """
  def batch_size(), do: @batch_size
end
