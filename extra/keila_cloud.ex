defmodule KeilaCloud do
  require Logger

  @cloud System.get_env("KEILA_CLOUD") in ["1", "true", "TRUE"]

  def __mix_recompile__?() do
    @cloud != System.get_env("KEILA_CLOUD") in ["1", "true", "TRUE"]
  end

  def cloud? do
    @cloud
  end

  if @cloud do
    license = System.get_env("KEILA_CLOUD_LICENSE", "")

    if !match?({:ok, %{type: "Keila Cloud"}}, Keila.License.validate(license)) do
      Logger.error("Valid license required for compiling Keila Cloud.")
      Logger.flush()
      System.halt(1)
    end
  end
end
