defmodule KeilaWeb.ContactsCsvExport do
  @moduledoc """
  Shared logic of exporting list of contacts to CSV file with support of streaming.
  """
  alias Keila.Contacts
  import Plug.Conn

  @chunk_size Application.compile_env!(:keila, KeilaWeb.ContactsCsvExport)[:chunk_size]

  def stream_csv_response(conn, filename, project_id, stream_opts \\ []) do
    stream_opts = Keyword.merge(stream_opts, max_rown: @chunk_size)

    conn =
      conn
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> put_resp_header("content-type", "text/csv")
      |> send_chunked(200)

    header =
      [["Email", "First name", "Last name", "Data", "Status"]]
      |> NimbleCSV.RFC4180.dump_to_iodata()
      |> IO.iodata_to_binary()

    {:ok, conn} = chunk(conn, header)

    Keila.Repo.transaction(fn ->
      Contacts.stream_project_contacts(project_id, stream_opts)
      |> Stream.map(fn contact ->
        data = if is_nil(contact.data), do: nil, else: Jason.encode!(contact.data)

        [[contact.email, contact.first_name, contact.last_name, data, contact.status]]
        |> NimbleCSV.RFC4180.dump_to_iodata()
        |> IO.iodata_to_binary()
      end)
      |> Stream.chunk_every(@chunk_size)
      |> Enum.reduce_while(conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> {:cont, conn}
          {:error, :closed} -> {:halt, conn}
        end
      end)
    end)
    |> then(fn {:ok, conn} -> conn end)
  end
end
