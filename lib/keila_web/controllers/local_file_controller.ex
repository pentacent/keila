defmodule KeilaWeb.LocalFileController do
  use KeilaWeb, :controller

  @spec serve(Conn.t(), map()) :: Conn.t()
  def serve(conn, %{"filename" => filename}) do
    if serve?() do
      with {:ok, path} <- Keila.Files.StorageAdapters.Local.get_path(filename),
           true <- File.exists?(path) do
        send_file(conn, 200, path)
      else
        _ -> resp(conn, 404, "File not found")
      end
    else
      conn
      |> resp(404, "File not found")
    end
  end

  defp serve? do
    Application.get_env(:keila, Keila.Files.StorageAdapters.Local) |> Keyword.get(:serve)
  end
end
