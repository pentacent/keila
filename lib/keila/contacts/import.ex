NimbleCSV.define(Keila.Contacts.Import.ExcelCSV,
  separator: ";",
  escape: "\"",
  line_separator: "\r\n",
  moduledoc: false
)

defmodule Keila.Contacts.Import do
  @moduledoc false

  use Keila.Repo
  import KeilaWeb.Gettext
  alias Keila.Contacts.{Contact, ImportError}

  @doc """
  Imports csv file and create new `Contacts` on database.

  ## Options
    - `:notify` - pid used to send messages about upload progress
    - `:on_conflict`:
      - `:replace`: replace contacts that have the same email address to the latest information on the CSV (or already on database)
      - `:ignore`: ignore contacts that already exists on database and will do nothing
  """
  @spec import_csv(Keila.Projects.Project.id(), String.t(), Keyword.t()) ::
          :ok | {:error, String.t()}
  def import_csv(project_id, filename, opts) do
    notify_pid = Keyword.get(opts, :notify, self())
    on_conflict = Keyword.get(opts, :on_conflict, :replace)

    Repo.transaction(
      fn ->
        try do
          import_csv!(project_id, filename, notify_pid, on_conflict)
        rescue
          e in NimbleCSV.ParseError ->
            Repo.rollback(e.message)

          e in Keila.Contacts.ImportError ->
            Repo.rollback(e.message)

          _e ->
            Repo.rollback(gettext("The file you provided could not be processed."))
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

  defp import_csv!(project_id, filename, notify_pid, on_conflict) do
    first_line = read_first_line!(filename)
    parser = determine_parser(first_line)
    row_function = build_row_function(parser, first_line, project_id)

    lines = read_file_line_count!(filename)
    send(notify_pid, {:contacts_import_progress, 0, lines})

    File.stream!(filename)
    |> parser.parse_stream()
    |> Stream.map(row_function)
    |> Stream.reject(&is_nil/1)
    |> Stream.with_index()
    |> Stream.map(fn {changeset, n} ->
      case insert(changeset, n, project_id, on_conflict) do
        {:ok, %{id: id}} ->
          Keila.Tracking.log_event("import", id, %{})
          n

        {:error, changeset} ->
          raise_import_error!(changeset, n + 1)
      end
    end)
    |> Stream.chunk_every(100)
    |> Enum.each(fn ns ->
      send(notify_pid, {:contacts_import_progress, List.last(ns) + 1, lines})
    end)
  end

  defp read_first_line!(filename) do
    File.open!(filename, fn file ->
      IO.read(file, :line)
    end)
  end

  defp determine_parser(first_line) do
    cond do
      String.split(first_line, ";") |> Enum.count() == 3 ->
        Keila.Contacts.Import.ExcelCSV

      true ->
        NimbleCSV.RFC4180
    end
  end

  defp build_row_function(parser, first_line, project_id) do
    headers =
      first_line
      |> parser.parse_string(skip_headers: false)
      |> hd()

    columns =
      [
        email: find_header_column(headers, ~r{email.?(address)?}i),
        external_id: find_header_column(headers, ~r{external.?id}i),
        first_name: find_header_column(headers, ~r{first.?name}i),
        last_name: find_header_column(headers, ~r{last.?name}i),
        data: find_header_column(headers, ~r{data}i),
        status: find_header_column(headers, ~r{status}i)
      ]
      |> Enum.filter(fn {_key, column} -> not is_nil(column) end)
      |> Enum.sort_by(fn {_key, column} -> column end)
      |> Enum.map(fn {key, _} -> key end)

    fn row ->
      Enum.zip(columns, row)
      |> Enum.into(%{})
      |> Map.update(:data, nil, &update_data_param/1)
      |> then(fn row ->
        unless contact_not_active?(row) do
          Contact.creation_changeset(row, project_id)
        end
      end)
    end
  end

  defp find_header_column(headers, regex) do
    Enum.find_index(headers, fn column -> column =~ regex end)
  end

  defp update_data_param(data) when data not in [nil, ""] do
    case Jason.decode(data) do
      {:ok, data} when is_map(data) -> data
      _ -> data
    end
  end

  defp update_data_param(_), do: nil

  # If the :status column is present, it must be "active"
  defp contact_not_active?(row)

  defp contact_not_active?(%{status: status}) when is_binary(status) do
    if status =~ ~r{active}i do
      false
    else
      true
    end
  end

  defp contact_not_active?(%{status: _}), do: false

  defp contact_not_active?(_), do: false

  defp read_file_line_count!(filename) do
    File.stream!(filename)
    |> Enum.count()
    |> then(fn lines -> max(lines - 1, 0) end)
  end

  defp insert(changeset, _n, _project_id, :ignore) do
    Repo.insert(changeset, on_conflict: :nothing)
  end

  defp insert(changeset, n, project_id, :replace) do
    external_id = get_change(changeset, :external_id)

    if not is_nil(external_id) do
      maybe_pre_set_external_id(changeset, project_id, external_id)
    end

    insert_opts = replace_insert_opts(changeset, external_id)
    Repo.insert(changeset, insert_opts)
  rescue
    e in Postgrex.Error ->
      raise_import_error!(changeset, e, n + 1)
  end

  @replace_fields [:email, :external_id, :first_name, :last_name, :data, :updated_at, :status]
  defp replace_insert_opts(changeset, external_id) do
    external_id? = not is_nil(external_id)

    replace_fields =
      @replace_fields
      |> Enum.filter(&(not is_nil(get_change(changeset, &1))))

    conflict_target =
      if external_id?, do: [:external_id, :project_id], else: [:email, :project_id]

    [
      conflict_target: conflict_target,
      on_conflict: {:replace, replace_fields},
      returning: false
    ]
  end

  # This is necessary because Postgres doesn't allow using both email and
  # external_id as conflict targets. Because of this and to allow updating
  # existing Contacts that don't have an external ID yet, this function
  # sets the external ID for such contacts before they are updated.
  defp maybe_pre_set_external_id(changeset, project_id, external_id) do
    email = get_change(changeset, :email)

    if not is_nil(email) do
      from(c in Contact,
        where: c.project_id == ^project_id and c.email == ^email and is_nil(c.external_id),
        update: [set: [external_id: ^external_id]]
      )
      |> Repo.update_all([])
    end
  end

  defp raise_import_error!(changeset, exception \\ nil, line) do
    message =
      case {changeset, exception} do
        {_, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
          gettext("duplicate entry")

        {%{errors: [{field, {message, _}} | _]}, _} ->
          gettext("Field %{field}: %{message}", field: field, message: message)

        _other ->
          gettext("unknown data error")
      end

    raise ImportError,
      message:
        gettext("Error importing contact in line %{line} (email: %{email}): %{message}",
          line: line,
          message: message,
          email: get_field(changeset, :email)
        ),
      line: line
  end
end
