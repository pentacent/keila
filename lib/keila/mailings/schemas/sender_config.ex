defmodule Keila.Mailings.Sender.Config do
  use Ecto.Schema
  alias Keila.Mailings.SenderAdapters
  alias Ecto.Changeset
  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @adapter_names SenderAdapters.adapter_names() ++ SenderAdapters.shared_adapter_names()

  embedded_schema do
    field :type, :string

    SenderAdapters.schema_fields() |> Enum.each(fn {name, type} -> field(name, type) end)
  end

  @spec changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type])
    |> validate_inclusion(:type, @adapter_names)
    |> cast_sender_adapter(params)
  end

  defp cast_sender_adapter(changeset, params) do
    adapter =
      Changeset.get_field(changeset, :type)
      |> SenderAdapters.get_adapter()

    if adapter do
      adapter.changeset(changeset, params)
    else
      changeset
    end
  end
end
