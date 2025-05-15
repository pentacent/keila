defmodule Keila.Instance do
  alias __MODULE__.Instance
  alias __MODULE__.Release

  use Keila.Repo
  require Logger

  @moduledoc """
  This module provides easier access to the properties of the current Keila instance.
  """

  @doc """
  Returns the `Instance` struct that is persisted in the database.
  If it doesn't exist, creates a new `Instance` and returns it.
  """
  @spec get_instance() :: Instance.t()
  def get_instance() do
    case Repo.one(Instance) do
      nil -> Repo.insert!(%Instance{})
      instance -> instance
    end
  end

  @doc """
  Returns the version of the current Keila instance as a string.
  """
  @spec current_version() :: String.t()
  def current_version() do
    Application.spec(:keila, :vsn) |> to_string()
  end

  @doc """
  Returns `true` if the update check has been enabled for the current instance.
  """
  @spec update_checks_enabled? :: boolean()
  def update_checks_enabled? do
    Application.get_env(:keila, :update_checks_enabled, true)
  end

  @doc """
  Returns `true` if updates are available.
  """
  @spec updates_available? :: boolean()
  def updates_available? do
    update_checks_enabled?() &&
      Repo.exists?(
        from i in Instance, where: fragment("jsonb_array_length(?) > 0", i.available_updates)
      )
  end

  @doc """
  Fetches updates from the Keila GitHub update releases.
  """
  @release_url "https://api.github.com/repos/pentacent/keila/releases"
  @spec fetch_updates() :: [__MODULE__.Release.t()]
  def fetch_updates() do
    with {:ok, response} <- HTTPoison.get(@release_url, recv_timeout: 5_000),
         {:ok, release_attrs} when is_list(release_attrs) <- Jason.decode(response.body) do
      current_version = current_version() |> Version.parse!()

      release_attrs
      |> Enum.map(fn %{"tag_name" => version, "published_at" => published_at, "body" => changelog} ->
        %{version: version, published_at: published_at, changelog: changelog}
      end)
      |> Enum.map(&Release.new!/1)
      |> Enum.filter(fn %{version: version} ->
        version |> Version.parse!() |> Version.compare(current_version) == :gt
      end)
    else
      other ->
        Logger.info("Unable to fetch updates. Got: #{inspect(other)}")
        []
    end
  end

  def get_available_updates() do
    if update_checks_enabled?() do
      Repo.one(from i in Instance, select: i.available_updates)
    else
      []
    end
  end
end
