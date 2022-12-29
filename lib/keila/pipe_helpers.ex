defmodule Keila.PipeHelpers do
  def tap_if_not_nil(value, fun)
  def tap_if_not_nil(nil, _), do: nil

  def tap_if_not_nil(value, fun) do
    fun.(value)
    value
  end
end
