defmodule KeilaWeb.LocalFileController do
  use KeilaWeb, :controller

  @spec serve(Conn.t(), map()) :: Conn.t()
  def serve(conn, %{"filename" => filename}) do
    if serve?() do
      with {:ok, path} <- Keila.Files.StorageAdapters.Local.get_path(filename),
           true <- File.exists?(path),
           {:ok, content_type} <- Keila.Files.MediaType.type_from_filename(filename) do
        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, path)
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
