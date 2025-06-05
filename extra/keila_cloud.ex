defmodule KeilaCloud do
  @cloud System.get_env("KEILA_CLOUD") in ["1", "true", "TRUE"]

  def __mix_recompile__?() do
    @cloud != System.get_env("KEILA_CLOUD") in ["1", "true", "TRUE"]
  end

  def cloud? do
    @cloud
  end
end
