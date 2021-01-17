defmodule Keila.Contacts do
  @moduledoc """
  Context for handling Contacts.

  Use this module to create/update/delete, verify, and import Contacts.
  """
  use Keila.Repo
  alias Keila.Projects.Project
  alias __MODULE__.{Contact, Import, Form}

  @doc """
  Creates a new Contact within the given Project.
  """
  @spec create_contact(Project.id(), map()) ::
          {:ok, Contact.t()} | {:error, Changeset.t(Contact.t())}
  def create_contact(project_id, params) when is_binary(project_id) or is_integer(project_id) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Contact.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Creates a new Contact within the given Project with dynamic cast and validation options.

  Options:
  - `:required` - List of required fields. Defaults to `[:email]`.
  - `:cast` - List of fields to be cast from params. Automatically includes fields specified as required.
  """
  @spec create_contact(Project.id(), map(), Keyword.t()) ::
          {:ok, Contact.t()} | {:error, Changeset.t(Contact.t())}
  def create_contact(project_id, params, opts) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Contact.dynamic_changeset(opts)
    |> Repo.insert()
  end

  @doc """
  Updates the specified Contact.
  """
  @spec update_contact(Contact.id(), map()) :: {:ok, Contact} | {:error, Contact}
  def update_contact(id, params) do
    get_contact(id)
    |> Contact.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Retrieves the specified Contact. Returns `nil` if Contact couldn‘t be found.
  """
  @spec get_contact(Contact.id()) :: Contact.t() | nil
  def get_contact(id) when is_binary(id) or is_integer(id) do
    Repo.get(Contact, id)
  end

  @doc """
  Gets specified Contact within Project context. Returns `nil` if Contact couldn‘t be found
  or belongs to a different Project.
  """
  @spec get_project_contact(Project.id(), Contact.id()) :: Contact.t() | nil
  def get_project_contact(project_id, contact_id) do
    case get_contact(contact_id) do
      contact = %{project_id: ^project_id} -> contact
      _other -> nil
    end
  end

  @doc """
  Returns Contacts for specified Project.

  This function accepts options for the `Keila.Contacts.Query` and `Keila.Contacts.Pagination` modules:
  - `:paginate` - `true` or Pagination options.
  - `:filter` - Query filter options.
  - `:sort` - Query sort options.

  If `:pagination` is not `true` or a list of options, a list of all results is returned.
  """
  @spec get_project_contacts(Project.id(), [Query.opts() | {:paginate, boolean() | Keyword.t()}]) ::
          Keila.Pagination.t(Contact.t()) | [Contact.t()]
  def get_project_contacts(project_id, opts \\ [])
      when is_binary(project_id) or is_integer(project_id) do
    query =
      from(c in Contact, where: c.project_id == ^project_id)
      |> Keila.Contacts.Query.apply(Keyword.take(opts, [:filter, :sort]))

    case Keyword.get(opts, :paginate) do
      true -> Keila.Pagination.paginate(query)
      opts when is_list(opts) -> Keila.Pagination.paginate(query, opts)
      _ -> Repo.all(query)
    end
  end

  @doc """
  Deletes specified Contact.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_contact(Contact.id()) :: :ok
  def delete_contact(id) do
    from(c in Contact, where: c.id == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes contacts from specified project.

  If you want to delete contacts by ID and make sure it happens within the
  context of a given project, use the `%{"id" => %{"in" => [...]}}` filter.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_project_contacts(any, filter: map(), sort: map()) :: :ok
  def delete_project_contacts(project_id, opts \\ []) do
    from(c in Contact, where: c.project_id == ^project_id)
    |> Keila.Contacts.Query.apply(opts |> Keyword.put(:sort, false))
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Imports Contacts from an RFC 4180-compliant CSV file.

  Progress is reported by sending messages to `notify_pid`
  with the format `{:contacts_import_progress, imported_contacts, import_total}`

  The structure of the CSV file has to be:
  | Email        | First name | Last name  |
  | ------------ |------------| ---------- |
  | foo@example.com | Foo     | Bar        |

  The `First name` and `Last name` columns can be empty but must be present.

  ## Options
  - `:notify` - PID of the process that is going to be sent progress notifications. Defaults to `self()`.
  """
  @spec import_csv(Keila.Projects.Project.id(), String.t(), Keyword.t()) ::
          :ok | {:error, String.t()}
  def import_csv(project_id, filename, opts \\ []) do
    opts = Keyword.put_new(opts, :notify, self())
    Import.import_csv(project_id, filename, opts)
  end

  @doc """
  Retrieves Form with specified `form_id`.
  """
  @spec get_form(Form.id()) :: Form.t() | nil
  def get_form(id) when is_binary(id) or is_integer(id),
    do: Repo.get(Form, id)

  def get_form(_),
    do: nil

  @doc """
  Retrieves Form with specified `form_id` if it belongs to the specified Project.
  """
  @spec get_project_form(Project.id(), Form.id()) :: Form.t() | nil
  def get_project_form(project_id, form_id) do
    case get_form(form_id) do
      form = %Form{project_id: ^project_id} -> form
      _other -> nil
    end
  end

  @doc """
  Retrieves all Forms for specified `project_id`.
  """
  @spec get_project_forms(Project.id()) :: [Form.t()]
  def get_project_forms(project_id) do
    from(f in Form, where: f.project_id == ^project_id)
    |> Repo.all()
  end

  @doc """
  Creates a new Form.
  """
  @spec create_form(Project.id(), map()) :: {:ok, Form.t()} | {:error, Changeset.t(Form.t())}
  def create_form(project_id, params) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Form.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates the specified Form.
  """
  @spec update_form(Form.id(), map()) :: {:ok, Form.t()} | {:error, Changeset.t(Form.t())}
  def update_form(form_id, params) do
    form_id
    |> get_form()
    |> Form.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes the specified form.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_form(Form.id()) :: :ok
  def delete_form(form_id) do
    from(f in Form, where: f.id == ^form_id)
    |> Repo.delete_all()

    :ok
  end
end
