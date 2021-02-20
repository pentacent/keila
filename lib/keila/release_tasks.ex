defmodule Keila.ReleaseTasks do
  @moduledoc """
  One-off commands you can run on Keila releases.

  Run the functions from this module like this:
  `bin/keila eval "Keila.ReleaseTasks.init()"`

  If you’re using the official Docker image, run them like this:
  `docker run pentacent/keila eval "Keila.ReleaseTasks.init()"`
  """

  @doc """
  Initializes the database and inserts fixtues.
  """
  def init() do
    migrate()
    Ecto.Migrator.with_repo(Keila.Repo, fn _ -> Code.eval_file("priv/repo/seeds.exs") end)
  end

  @doc """
  Runs database migrations.
  """
  def migrate do
    {:ok, _, _} = Ecto.Migrator.with_repo(Keila.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  @doc """
  Rolls back database migrations to given version.
  """
  def rollback(version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(Keila.Repo, &Ecto.Migrator.run(&1, :down, to: version))
  end
end
