defmodule Keila.Auth.Permission do
  use Keila.Schema, prefix: "ap"

  schema "permissions" do
    field(:name, :string)

    timestamps()
  end

  @spec changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
  end
end
