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

  @spec import_csv(Keila.Projects.Project.id(), String.t(), Keyword.t()) ::
          :ok | {:error, String.t()}
  def import_csv(project_id, filename, opts) do
    notify_pid = Keyword.get(opts, :notify, self())

    Repo.transaction(
      fn ->
        try do
          import_csv!(project_id, filename, notify_pid)
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

  defp import_csv!(project_id, filename, notify_pid) do
    parser = determine_parser(filename)

    lines =
      File.stream!(filename)
      |> parser.parse_stream()
      |> Enum.count()

    send(notify_pid, {:contacts_import_progress, 0, lines})

    File.stream!(filename)
    |> parser.parse_stream()
    |> Stream.map(fn [email, first_name, last_name] ->
      Contact.creation_changeset(%{
        email: email,
        first_name: first_name,
        last_name: last_name,
        project_id: project_id
      })
    end)
    |> Stream.with_index()
    |> Stream.map(fn {changeset, n} ->
      case Repo.insert(changeset, returning: false) do
        {:ok, _} -> n
        {:error, changeset} -> raise_import_error!(changeset, n + 1)
      end
    end)
    |> Stream.chunk_every(100)
    |> Enum.each(fn ns ->
      send(notify_pid, {:contacts_import_progress, List.last(ns) + 1, lines})
    end)
  end

  defp determine_parser(filename) do
    file = File.open!(filename)
    first_line = IO.read(file, :line)
    File.close(file)

    cond do
      String.split(first_line, ";") |> Enum.count() == 3 ->
        Keila.Contacts.Import.ExcelCSV

      true ->
        NimbleCSV.RFC4180
    end
  end

  defp raise_import_error!(changeset, line) do
    message =
      case changeset.errors do
        [{field, {message, _}} | _] ->
          gettext("Field %{field}: %{message}", field: field, message: message)

        _other ->
          gettext("unknown data error")
      end

    raise ImportError,
      message:
        gettext("Error importing contact in line %{line}: %{message}",
          line: line,
          message: message
        ),
      line: line
  end
end
