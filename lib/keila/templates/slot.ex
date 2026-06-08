defmodule Keila.Templates.Slot do
  @moduledoc """
  A parsed keila-content slot definition: the slot's `name` and its `default_content`
  """

  @enforce_keys [:name, :default_content]
  defstruct [:name, :default_content]

  @type t :: %__MODULE__{name: String.t(), default_content: String.t() | nil}
end
