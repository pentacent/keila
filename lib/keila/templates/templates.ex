defmodule Keila.Templates do
  @moduledoc """
  Context for building and managing templates.

  The following submodules are intended for direct use as well:
  - `Keila.Templates.HybridTemplate`
  - `Keila.Templates.Html`
  - `Keila.Templates.Css`
  - `Keila.Templates.StyleTemplate`
  """

  use Keila.Repo
  alias __MODULE__.{Template}

  defdelegate get_content_slots(input, opts), to: __MODULE__.ContentSlots
  defdelegate merge_content_slots(input, content, opts \\ []), to: __MODULE__.ContentSlots

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

  Options:
    * `:type` - filter by template type. Accepts a single atom (e.g. `:mjml`)
      or a list of atoms (e.g. `[:mjml, :html]`).
  """
  @spec get_project_templates(Project.id(), keyword()) :: [Template.t()]
  def get_project_templates(project_id, opts \\ []) when is_id(project_id) do
    from(t in Template, where: t.project_id == ^project_id, order_by: [desc: t.updated_at])
    |> maybe_filter_template_type(opts[:type])
    |> Repo.all()
  end

  defp maybe_filter_template_type(query, nil), do: query

  defp maybe_filter_template_type(query, type) when is_atom(type) do
    from(t in query, where: t.type == ^type)
  end

  defp maybe_filter_template_type(query, types) when is_list(types) do
    from(t in query, where: t.type in ^types)
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
    |> delete_templates()
  end

  @doc """
  Deletes Templates with given IDs but only if they belong to Project specified by `project_id`.

  This function is idempotent and always returns `:ok`
  """
  def delete_project_templates(project_id, ids) when is_id(project_id) do
    from(t in Template, where: t.id in ^ids and t.project_id == ^project_id)
    |> delete_templates()
  end

  defp delete_templates(query) do
    Repo.transaction(fn ->
      {_count, deleted} = query |> select([t], {t.project_id, t.id}) |> Repo.delete_all()

      deleted
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.each(fn {project_id, template_ids} ->
        :ok = replace_project_email_templates(project_id, template_ids, nil)
      end)
    end)

    :ok
  end

  # List of all embedded `Email` structs in the database.
  # Should be kept up-to-date for pruning of referenced template IDs.
  @email_embeds [
    {Keila.Contacts.Form, :welcome_email},
    {Keila.Contacts.Form, :double_opt_in_email}
  ]

  @doc """
  Replaces the template_id of all embedded `Keila.Mailings.Email`s in the
  specified project which match the given `template_ids`.
  `replacement_id` may be the ID of another template in the project or `nil`.

  Returns `{:error, :template_not_found}` if no template with `replacement_id`
  could be found in the project.
  """
  @spec replace_project_email_templates(
          Project.id(),
          [Template.id()],
          Template.id() | nil
        ) :: :ok | {:error, :template_not_found}
  def replace_project_email_templates(project_id, template_ids, replacement_id)
      when is_id(project_id) do
    if is_nil(replacement_id) or get_project_template(project_id, replacement_id) do
      stored_ids = Enum.flat_map(template_ids, &stored_template_ids/1)
      {:ok, replacement_id} = Ecto.Type.cast(Template.Id, replacement_id)

      for {schema, field} <- @email_embeds do
        email =
          dynamic(
            [e],
            fragment(
              "jsonb_set(?, '{template_id}', coalesce(to_jsonb(?::text), 'null'))",
              field(e, ^field),
              ^replacement_id
            )
          )

        from(e in schema,
          where: e.project_id == ^project_id,
          where: fragment("?->>'template_id' = ANY(?)", field(e, ^field), ^stored_ids),
          update: [set: ^[{field, email}]]
        )
        |> Repo.update_all([])
      end

      :ok
    else
      {:error, :template_not_found}
    end
  end

  # Emails may store template ids as hashids or as integers
  defp stored_template_ids(template_id) do
    {:ok, hashid} = Ecto.Type.cast(Template.Id, template_id)
    {:ok, integer_id} = Template.Id.dump(hashid)
    [hashid, to_string(integer_id)]
  end
end
