defmodule Keila.Contacts.FormParamsPruner do
  @moduledoc """
  Oban cron worker that periodically executes the `Contacts.prune_form_params/1` function.
  """

  use Oban.Worker,
    queue: :system,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing]
    ]

  alias Keila.Contacts

  @batch_size 10_000

  @impl true
  def perform(_job) do
    case Contacts.prune_form_params(@batch_size) do
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
