defmodule Keila.Instance.UpdateCronWorker do
  use Oban.Worker,
    queue: :updater,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing]
    ]

  use Keila.Repo
  alias Keila.Instance

  @impl true
  def perform(_job) do
    if Instance.update_checks_enabled?() do
      releases = Instance.fetch_updates()

      Instance.get_instance()
      |> change()
      |> put_embed(:available_updates, releases)
      |> Repo.update()
    else
      :ok
    end
  end
end
