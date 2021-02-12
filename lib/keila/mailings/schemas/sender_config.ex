defmodule Keila.Mailings.Sender.Config do
  use Ecto.Schema
  alias Keila.Mailings.SenderAdapters
  alias Ecto.Changeset
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :type, :string

    SenderAdapters.schema_fields() |> Enum.each(fn {name, type} -> field(name, type) end)
  end

  @spec changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type])
    |> validate_inclusion(:type, SenderAdapters.adapter_names())
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

  @doc """
  Converts the embedded schema to Keyword list for use with Swoosh.
  """
  @spec to_swoosh_config(t()) :: Keyword.t()
  def to_swoosh_config(struct = %__MODULE__{}) do
    adapter = SenderAdapters.get_adapter(struct.type)

    adapter.to_swoosh_config(struct)
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
  end
end
