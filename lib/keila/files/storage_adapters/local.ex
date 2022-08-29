defmodule Keila.Files.StorageAdapters.Local do
  @behaviour Keila.Files.StorageAdapters.Adapter

  @impl true
  def name() do
    "local"
  end

  @impl true
  def store(source, metadata) do
    uuid = metadata[:uuid]

    extension =
      case metadata[:filename] do
        filename when is_binary(filename) -> Path.extname(filename)
        _other -> ""
      end

    filename = uuid <> extension
    dir = get_dir()
    File.mkdir_p!(dir)
    destination = Path.join(dir, filename)
    File.cp!(source, destination)

    %{"local_filename" => filename}
  end

  @impl true
  def delete(file) do
    {:ok, path} = get_path(file)
    File.rm(path)
  end

  @impl true
  def get_url(file) do
    serve? = Application.get_env(:keila, __MODULE__) |> Keyword.fetch!(:dir)

    if serve? do
      KeilaWeb.Router.Helpers.local_file_url(
        KeilaWeb.Endpoint,
        :serve,
        file.adapter_data["local_filename"]
      )
    else
      Application.get_env(:keila, __MODULE__)
      |> Keyword.fetch!(:base_url)
      |> URI.merge(file.adapter_data["local_filename"])
      |> URI.to_string()
    end
  end

  defp get_dir() do
    Application.get_env(:keila, __MODULE__) |> Keyword.fetch!(:dir)
  end

  @doc """
  Return the local file path for a given file struct or filename.

  Returns `{:ok, path}` if valid inputs were provided.
  Returns `:error` for attempted directory traversals.

  **Note**:  This function doesn’t check if the file actually exists.
  """
  @spec get_path(File.t() | String.t()) :: {:ok, String.t()} | :error
  def get_path(file) when is_struct(file) do
    %{adapter_data: %{"local_filename" => filename}} = file
    {:ok, Path.join(get_dir(), filename)}
  end

  def get_path(filename) when is_binary(filename) do
    path = Path.join(get_dir(), filename)

    # Prevent directory traversals
    if path == Path.expand(path) do
      {:ok, path}
    else
      :error
    end
  end
end
