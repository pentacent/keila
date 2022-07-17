defmodule Keila.FileCase do
  @moduledoc """
  Helper module for running tests with the Keila.File module.
  """

  defmacro __using__(_opts) do
    quote do
      alias Keila.Files

      setup do
        dir =
          [System.tmp_dir!(), :crypto.strong_rand_bytes(32) |> Base.encode16()]
          |> Path.join()

        File.mkdir_p!(dir)

        # Temporarily override StorageAdapter configuration
        local_adapter_config = Application.get_env(:keila, Keila.Files.StorageAdapters.Local)

        Application.put_env(
          :keila,
          Keila.Files.StorageAdapters.Local,
          local_adapter_config |> Keyword.put(:dir, dir) |> Keyword.put(:serve, true)
        )

        on_exit(fn ->
          File.rm_rf!(dir)
          Application.put_env(:keila, Keila.Files.StorageAdapters.Local, local_adapter_config)
        end)

        %{dir: dir}
      end
    end
  end
end
