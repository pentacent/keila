defmodule Keila.Contacts do
  @moduledoc """
  Context for handling Contacts.

  Use this module to create/update/delete, verify, and import Contacts.
  """
  use Keila.Repo
  alias Keila.Projects.Project
  alias __MODULE__.{Contact, Import, Form, FormParams, Segment}
  import KeilaWeb.Gettext

  @doc """
  Creates a new Contact within the given Project.


  ## Options
  - `:set_status` - Also sets the `status` field from `params` when `true`.
  """
  @spec create_contact(Project.id(), map(), Keyword.t()) ::
          {:ok, Contact.t()} | {:error, Changeset.t(Contact.t())}
  def create_contact(project_id, params, opts \\ [])
      when is_binary(project_id) or is_integer(project_id) do
    Contact.creation_changeset(%Contact{}, params, project_id)
    |> maybe_update_contact_status(params, opts[:set_status])
    |> Repo.insert()
  end

  defp maybe_update_contact_status(changeset, params, update?)

  defp maybe_update_contact_status(changeset, params, true),
    do: Contact.update_status_changeset(changeset, params)

  defp maybe_update_contact_status(changeset, _params, _), do: changeset

  defdelegate perform_form_action(form, params, opts), to: __MODULE__.FormActionHandler
  defdelegate perform_form_action(form, params), to: __MODULE__.FormActionHandler

  @doc """
  Updates the specified Contact.

  ## Options
  - `:update_status` - Also updates the `status` field from `params` when `true`.
  """
  @spec update_contact(Contact.id(), map(), Keyword.t()) :: {:ok, Contact} | {:error, Contact}
  def update_contact(id, params, opts \\ []) do
    get_contact(id)
    |> Contact.update_changeset(params)
    |> maybe_update_contact_status(params, opts[:update_status])
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
    Repo.get_by(Contact, project_id: project_id, id: contact_id)
  end

  @doc """
  Gets the Contact with the given `email` address within Project context.
  Returns `nil` if Contact couldn‘t be found.
  """
  @spec get_project_contact_by_email(Project.id(), String.t()) :: Contact.t() | nil
  def get_project_contact_by_email(project_id, email) do
    Repo.get_by(Contact, project_id: project_id, email: email)
  end

  @doc """
  Gets specified Contact within Project context. Returns `nil` if Contact couldn‘t be found
  or belongs to a different Project.
  """
  @spec get_project_contact_by_external_id(Project.id(), external_id :: String.t()) ::
          Contact.t() | nil
  def get_project_contact_by_external_id(project_id, external_id) do
    Repo.get_by(Contact, project_id: project_id, external_id: external_id)
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
  | Email        | First name | Last name  | Data | Status | External ID |
  | ------------ |------------| ---------- | ---- | ------ | ----------- |
  | foo@example.com | Foo     | Bar        | {}   | active | 123         |

  The `First name`, `Last name`, `Data`, `Status`, and `External ID` columns can be empty but must be present.
  
  Valid status values are: `active`, `unsubscribed`, `unreachable` (case-insensitive).
  If no status is provided or status column is missing, contacts default to `active`.

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
    |> Form.creation_changeset()
    |> put_change(:project_id, project_id)
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
          field: :email,
          label: gettext("Email"),
          placeholder: "",
          required: true,
          cast: true,
          type: :email
        }),
        Map.from_struct(%Form.FieldSettings{
          field: :first_name,
          label: gettext("First name"),
          placeholder: "",
          required: false,
          cast: false,
          type: :string
        }),
        Map.from_struct(%Form.FieldSettings{
          field: :last_name,
          label: gettext("Last name"),
          placeholder: "",
          required: false,
          cast: false,
          type: :string
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
  Creates a new `FormParams` entity for the given `Form` ID and `attrs` map.
  `FormParams` are used to implement the double opt-in mechanism; they are an
  intermediate storage for the attributes submitted by a contact who has
  submitted a signup form.
  """
  @spec create_form_params(Form.id(), map()) ::
          {:ok, FormParams.t()} | {:error, Changeset.t(FormParams.t())}
  def create_form_params(form_id, attrs) do
    FormParams.changeset(form_id, attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the `FormParams` entity for the given `id`. Returns `nil` if no such
  entity exists.
  """
  @spec get_form_params(FormParams.id()) :: FormParams.t() | nil
  def get_form_params(id) do
    Repo.get(FormParams, id)
  end

  @doc """
  Retrieves, deletes, and returns the `FormParams` entity with the given `id`.
  Returns `nil` if no such entity exists.
  """
  @spec get_and_delete_form_params(FormParams.id()) :: FormParams.t() | nil
  def get_and_delete_form_params(id) do
    from(fa in FormParams, where: fa.id == ^id, select: fa)
    |> Repo.delete_all()
    |> case do
      {1, [form_params]} -> form_params
      _ -> nil
    end
  end

  @doc """
  Deletes the `FormParams` entity with the given `id`. Always returns `:ok`.
  """
  @spec delete_form_params(FormParams.id()) :: :ok
  def delete_form_params(id) do
    from(fa in FormParams, where: fa.id == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Returns an HMAC string for the given `FormParams` ID that can be
  used when verifying a contact in the double opt-in process.
  """
  @spec double_opt_in_hmac(Form.id(), FormParams.id()) :: String.t()
  def double_opt_in_hmac(form_id, form_params_id) do
    key = Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.fetch!(:secret_key_base)
    message = "double-opt-in:" <> form_id <> ":" <> form_params_id

    :crypto.mac(:hmac, :sha256, key, message)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Verifies a HMAC string for the given `FormParams` ID.
  """
  @spec valid_double_opt_in_hmac?(String.t(), Form.id(), FormParams.id()) :: boolean()
  def valid_double_opt_in_hmac?(hmac, form_id, form_params_id) do
    case double_opt_in_hmac(form_id, form_params_id) do
      ^hmac -> true
      _other -> false
    end
  end

  @doc """
  Updates the status of a Contact.

  Returns `nil` if contact was not found.
  """
  @spec update_contact_status(Contact.id(), atom()) :: Contact.t() | nil
  def update_contact_status(contact_id, status) do
    with %Contact{} = contact <- get_contact(contact_id) do
      contact |> change(%{status: status}) |> Repo.update!()
    end
  end

  @doc """
  Downgrades the status of a contact to the given status if that status is
  lower than the previously stored value.

  Returns `nil` if contact was not found.
  """
  @spec downgrade_contact_status(Contact.id(), :unsubscribed | :unreachable) :: Contact.t() | nil
  def downgrade_contact_status(contact_id, :unsubscribed) do
    with %Contact{} = contact <- get_contact(contact_id) do
      if contact.status != :unsubscribed do
        contact |> change(%{status: :unreachable}) |> Repo.update!()
      else
        contact
      end
    end
  end

  def downgrade_contact_status(contact_id, :unreachable) do
    with %Contact{} = contact <- get_contact(contact_id) do
      if contact.status not in [:unsubscribed, :unreachable] do
        contact |> change(%{status: :unreachable}) |> Repo.update!()
      else
        contact
      end
    end
  end

  @doc """
  Creates a new Segment within the given Project.
  """
  @spec create_segment(Project.id(), map()) ::
          {:ok, Segment.t()} | {:error, Changeset.t(Segment.t())}
  def create_segment(project_id, params) when is_id(project_id) do
    params
    |> Segment.creation_changeset()
    |> put_change(:project_id, project_id)
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
    from(s in Segment, where: s.project_id == ^project_id, order_by: s.name)
    |> Repo.all()
  end
end
