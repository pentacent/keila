defmodule Keila.Contacts do
  @moduledoc """
  Context for handling Contacts.

  Use this module to create/update/delete, verify, and import Contacts.
  """
  alias __MODULE__.Contact
  alias Keila.Projects.Project
  use Keila.Repo

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
  Returns paginated Contacts for specified Project.
  """
  @spec get_project_contacts(Project.id(), list()) :: Keila.Pagination.t(Contact.t())
  def get_project_contacts(project_id, pagination_opts \\ [])
      when is_binary(project_id) or is_integer(project_id) do
    from(c in Contact, where: c.project_id == ^project_id)
    |> Keila.Pagination.paginate(pagination_opts)
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
  Imports Contacts from an RFC 4180-compliant CSV file.

  Progress is reported by sending messages to `notify_pid`
  with the format `{:contacts_import_progress, imported_contacts, import_total}`

  The structure of the CSV file has to be:
  | Email        | First name | Last name  |
  | ------------ |------------| ---------- |
  | foo@example.com | Foo     | Bar        |

  The `First name` and `Last name` columns can be empty but must be present.
  """
  @spec(import_csv(Project.id(), String.t()) :: :ok, {:error, String.t()})
  def import_csv(project_id, filename, notify_pid \\ self()) do
    Repo.transaction(
      fn ->
      try do
        import_csv!(project_id, filename, notify_pid)
      rescue
        e in NimbleCSV.ParseError ->
          Repo.rollback(e.message)

        e in Ecto.InvalidChangesetError ->
          Repo.rollback("invalid data: #{inspect(e.changeset.errors |> List.first())}")
      end
      end,
      timeout: :infinity,
      pool_timeout: :infinity
    )
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp import_csv!(project_id, filename, notify_pid) do
    lines =
      File.stream!(filename)
      |> NimbleCSV.RFC4180.parse_stream()
      |> Enum.count()

    send(notify_pid, {:contacts_import_progress, 0, lines})

    File.stream!(filename)
    |> NimbleCSV.RFC4180.parse_stream()
    |> Stream.map(fn [email, first_name, last_name] ->
      Contact.creation_changeset(%{
        email: email,
        first_name: first_name,
        last_name: last_name,
        project_id: project_id
      })
    end)
    |> Stream.map(&Repo.insert!(&1))
    |> Stream.with_index()
    |> Stream.map(fn {_, n} -> n end)
    |> Enum.chunk_every(100)
    |> Enum.each(fn ns ->
      send(notify_pid, {:contacts_import_progress, List.last(ns) + 1, lines})
    end)
  end
end
