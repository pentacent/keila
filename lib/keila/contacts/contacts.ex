defmodule Keila.Contacts do
  @moduledoc """
  Context for handling Contacts.

  Use this module to create/update/delete, verify, and import Contacts.
  """
  use Keila.Repo
  alias Keila.Projects.Project
  alias __MODULE__.{Contact, Import, Form, Event, Segment}
  import KeilaWeb.Gettext

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
  Creates a new Contact within the given Project with dynamic casts and
  validations based on the given form.
  """
  @spec create_contact_from_form(Project.id(), Form.t(), map()) ::
          {:ok, Contact.t()} | {:error, Changeset.t(Contact.t())}
  def create_contact_from_form(project_id, form, params) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Contact.changeset_from_form(form)
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
    opts = Keyword.put_new(opts, :sort, %{"inserted_at" => -1})

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
  Returns number of Contacts in specified project
  """
  @spec get_project_contacts_count(Project.id(), [Query.opts()]) :: integer()
  def get_project_contacts_count(project_id, opts \\ [])
      when is_binary(project_id) or is_integer(project_id) do
    opts = Keyword.put_new(opts, :sort, %{"inserted_at" => -1})

    from(c in Contact, where: c.project_id == ^project_id)
    |> Keila.Contacts.Query.apply(Keyword.take(opts, [:filter, :sort]))
    |> Repo.aggregate(:count, :id)
  end

  @spec get_project_contacts_stats(Project.id(), [Query.opts()]) :: %{
          active: integer(),
          unsubscribed: integer(),
          unreachable: integer()
        }
  def get_project_contacts_stats(project_id, opts \\ []) do
    query_opts = [sort: false] ++ Keyword.take(opts, [:filter])

    from(c in Contact, where: c.project_id == ^project_id)
    |> Keila.Contacts.Query.apply(query_opts)
    |> group_by([c], c.status)
    |> select([c], {c.status, count(c.id)})
    |> Repo.all()
    |> Enum.into(%{})
    |> Map.merge(%{active: 0, unsubscribed: 0, unreachable: 0}, fn _key, value1, value2 ->
      max(value1, value2)
    end)
  end

  def stream_project_contacts(project_id, opts)
      when is_binary(project_id) or is_integer(project_id) do
    opts = Keyword.put_new(opts, :sort, %{"inserted_at" => -1})

    query =
      from(c in Contact, where: c.project_id == ^project_id)
      |> Keila.Contacts.Query.apply(Keyword.take(opts, [:filter, :sort]))

    Repo.stream(query, max_rows: Keyword.get(opts, :max_rows, 100_000))
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
  @spec delete_project_contacts(Project.id(), filter: map(), sort: map()) :: :ok
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
    from(f in Form, where: f.project_id == ^project_id, order_by: [desc: f.updated_at])
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
  Creates a new Form with default settings.
  """
  @spec create_empty_form(Project.id()) :: {:ok, Form.t()}
  def create_empty_form(project_id) do
    form = %Form{
      project_id: project_id,
      name: gettext("My New Form"),
      settings:
        Map.from_struct(%Form.Settings{
          success_text: gettext("Thank you for signing up!")
        }),
      field_settings: [
        Map.from_struct(%Form.FieldSettings{
          field: "email",
          label: gettext("Email"),
          placeholder: "",
          required: true,
          cast: true
        }),
        Map.from_struct(%Form.FieldSettings{
          field: "first_name",
          label: gettext("First name"),
          placeholder: "",
          required: false,
          cast: false
        }),
        Map.from_struct(%Form.FieldSettings{
          field: "last_name",
          label: gettext("Last name"),
          placeholder: "",
          required: false,
          cast: false
        })
      ]
    }

    {:ok, Repo.insert!(form)}
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

  @doc """
  Deletes the specified forms if they belong to the specified project.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_project_forms(Project.id(), [Form.id()]) :: :ok
  def delete_project_forms(project_id, form_ids) do
    from(f in Form, where: f.id in ^form_ids and f.project_id == ^project_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Logs an Event and updates contact status accordingly.
  """
  @spec log_event(Contact.id(), String.t() | atom(), map()) ::
          {:ok, Event.t()} | {:error, Changeset.t(Event.t())}
  def log_event(contact_id, type, data \\ %{}) do
    %{contact_id: contact_id, type: type, data: data}
    |> Event.changeset()
    |> Repo.insert()
    |> tap(&maybe_update_contact_status/1)
  end

  defp maybe_update_contact_status({:ok, event}),
    do: update_contact_status(event.contact_id, event)

  defp maybe_update_contact_status(_), do: nil

  @doc """
  Returns list of all Events for given `contact_id`.
  Events are sorted from latest to oldest.
  """
  @spec get_contact_events(Contact.id()) :: [Event.t()]
  def get_contact_events(contact_id) do
    from(e in Event, where: e.contact_id == ^contact_id, order_by: [desc: e.inserted_at])
    |> Repo.all()
  end

  defp update_contact_status(contact_id, latest_event)

  defp update_contact_status(contact_id, %Event{type: type})
       when type in [:subscribe, :create, :import] do
    from(c in Contact, where: c.id == ^contact_id)
    |> Repo.update_all(set: [status: :active])
  end

  defp update_contact_status(contact_id, %Event{type: type})
       when type in [:unsubscribe, :complaint] do
    from(c in Contact, where: c.id == ^contact_id and c.status in [:active, :unreachable])
    |> Repo.update_all(set: [status: :unsubscribed])
  end

  defp update_contact_status(contact_id, %Event{type: :hard_bounce}) do
    from(c in Contact, where: c.id == ^contact_id and c.status in [:active])
    |> Repo.update_all(set: [status: :unreachable])
  end

  defp update_contact_status(_contact_id, _event) do
    # TODO Implement updating status without in without latest_event and make function public.
    :ok
  end

  @doc """
  Creates a new Segment within the given Project.
  """
  @spec create_segment(Project.id(), map()) ::
          {:ok, Segment.t()} | {:error, Changeset.t(Segment.t())}
  def create_segment(project_id, params) when is_id(project_id) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Segment.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates an existing Segment.
  """
  @spec update_segment(Segment.id(), map()) ::
          {:ok, Segment.t()} | {:error, Changeset.t(Segment.t())}
  def update_segment(id, params) when is_id(id) do
    get_segment(id)
    |> Segment.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes the specified Segment.

  This function is idempotent and always returns **:ok**
  """
  @spec delete_segment(Segment.id()) :: :ok
  def delete_segment(id) when is_id(id) do
    from(s in Segment, where: s.id == ^id) |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes the specified Segments within the context of the given Project.

  This function is idempotent and always returns **:ok**
  """
  @spec delete_project_segments(Project.id(), [Segment.id()]) :: :ok
  def delete_project_segments(project_id, ids) when is_id(project_id) do
    from(s in Segment, where: s.id in ^ids and s.project_id == ^project_id) |> Repo.delete_all()

    :ok
  end

  @doc """
  Retrieves the specified Segment. Returns `nil` if no Segment could be found.
  """
  @spec get_segment(Segment.id()) :: nil | Segment.t()
  def get_segment(id) when is_id(id) do
    Repo.get(Segment, id)
  end

  @doc """
  Retrieves the specified Segment if it belongs to the given Project.
  Returns `nil` if no Segment could be found or it doesn’t belong to the given
  Project.
  """
  @spec get_project_segment(Project.id(), Segment.id()) :: nil | Segment.t()
  def get_project_segment(project_id, id) when is_id(project_id) and is_id(id) do
    from(s in Segment, where: s.id == ^id and s.project_id == ^project_id)
    |> Repo.one()
  end

  @doc """
  Retrieves all Segments for the given Project.
  """
  @spec get_project_segments(Project.id()) :: [Segment.t()] | []
  def get_project_segments(project_id) when is_id(project_id) do
    from(s in Segment, where: s.project_id == ^project_id)
    |> Repo.all()
  end
end
