defmodule Keila.Templates do
  @moduledoc """
  Context for building and managing templates.

  The following submodules are intended for direct use as well:
  - `Keila.Templates.DefaultTemplate`
  - `Keila.Templates.Html`
  - `Keila.Templates.Css`
  - `Keila.Templates.StyleTemplate`
  """

  use Keila.Repo
  alias __MODULE__.{Template}

  @doc """
  Creates a new template.
  """
  @spec create_template(Project.id(), map()) ::
          {:ok, Template.t()} | {:error, Changeset.t(Template.t())}
  def create_template(project_id, params) when is_id(project_id) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Template.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Duplicates template specified by `template_id` and optionally applies
  changes given as `params`.
  """
  @spec clone_template(Template.id(), map()) ::
          {:ok, Template.t()} | {:error, Changeset.t(Template.t())}
  def clone_template(template_id, params \\ %{}) when is_id(template_id) do
    params =
      params
      |> stringize_params()
      |> Map.drop(["project_id"])

    template = get_template(template_id)

    template
    |> Map.from_struct()
    |> stringize_params()
    |> Map.merge(params)
    |> Template.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Retrieves Template with given `template_id`.
  """
  @spec get_template(Template.id()) :: nil | Template.t()
  def get_template(template_id) do
    Repo.get(Template, template_id)
  end

  @doc """
  Retrieves Template with given `template_id` only if it belongs to the specified Project.
  """
  @spec get_project_template(Project.id(), Template.id()) :: nil | Template.t()
  def get_project_template(project_id, template_id)
      when is_id(project_id) and is_id(template_id) do
    from(t in Template, where: t.id == ^template_id and t.project_id == ^project_id)
    |> Repo.one()
  end

  @doc """
  Returns all Templates belonging to specified Project.
  """
  @spec get_project_templates(Project.id()) :: [Template.t()]
  def get_project_templates(project_id) when is_id(project_id) do
    from(t in Template, where: t.project_id == ^project_id, order_by: [desc: t.updated_at])
    |> Repo.all()
  end

  @doc """
  Updates given template with `params`.
  """
  @spec update_template(Template.id(), map()) ::
          {:ok, Template.t()} | {:error, Changeset.t(Template.t())}
  def update_template(template_id, params) when is_id(template_id) do
    get_template(template_id)
    |> Template.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes given Template.

  This function is idempotent and always returns `:ok`
  """
  @spec delete_template(Template.id()) :: :ok
  def delete_template(template_id) when is_id(template_id) do
    from(t in Template, where: t.id == ^template_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes Templates with given IDs but only if they belong to Project specified by `project_id`.

  This function is idempotent and always returns `:ok`
  """
  def delete_project_templates(project_id, ids) when is_id(project_id) do
    from(t in Template, where: t.id in ^ids and t.project_id == ^project_id)
    |> Repo.delete_all()

    :ok
  end
end
