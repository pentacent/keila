defmodule Keila.Mailings.Campaign.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:type, Ecto.Enum, values: [:text])
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type])
  end
end
