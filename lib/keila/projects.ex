defmodule Keila.Projects do
  @moduledoc """
  Projects are a layer for multi-tenancy, implemented on top of `Auth.Group`.
  """
  use Keila.Repo
  alias Keila.Projects.Project
  alias Keila.Auth
  alias Keila.Auth.{User, Group}


  @doc """
  Creates a new Project.
  """
  @spec create_project(User.t(), map()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t(Project.t())}
  def create_project(user_id, params) do
    Repo.transaction(fn ->
      with {:ok, group} <- Auth.create_group(%{parent_id: Auth.root_group().id}),
      :ok <- Auth.add_user_to_group(user_id, group.id) do
        params = params
        |> Enum.map(fn {key, value} -> {to_string(key), value} end)
        |> Enum.into(%{})
        |> Map.put("group_id", group.id)
        changeset = Project.creation_changeset(params)
        Repo.insert(changeset)
      end
      |> case do
        {:ok, project = %Project{}} -> project
        {:error, changeset = %Changeset{}} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates an existing Project and returns updated struct.
  """
  @spec update_project(Project.id(), map()) :: {:ok, Project.t()} | {:error, Changeset.t(Project.t())}
  def update_project(id, params) when is_binary(id) or is_integer(id) do
    id
    |> get_project()
    |> Project.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes Project with given `id`.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_project(Project.id()) :: :ok
  def delete_project(id) do
    with project = %Project{} <- get_project(id) do
      Repo.delete_all(from(g in Group, where: g.id == ^(project.group_id)))
      Repo.delete_all(from(p in Project, where: p.id == ^(project.id)))
      :ok
    end
  end

  @doc """
  Returns `Project` with given `id`. Returns `nil` if Project doesn’t
  exist.
  """
  @spec get_project(Project.id()) :: Project.t() | nil
  def get_project(id) when is_binary(id) or is_integer(id),
    do: Repo.get(Project, id)

  def get_project(_),
    do: nil

  @spec projects_for_user(User.id()) :: [Project.t()]
  def projects_for_user(user_id) when is_binary(user_id) or is_integer(user_id) do
    # TODO Maybe use just one query. But: Respecting domain boundaries?
    user_group_ids = user_id
    |> Auth.list_user_groups()
    |> Enum.map(& &1.id)

    from(p in Project, where: p.group_id in ^user_group_ids)
    |> Repo.all()
  end
end
