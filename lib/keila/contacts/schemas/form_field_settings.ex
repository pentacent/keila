defmodule Keila.Contacts.Form.FieldSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:field, :string)
    field(:required, :boolean)
    field(:cast, :boolean)
    field(:label, :string)
    field(:placeholder, :string)
    field(:description, :string)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:field, :required, :cast, :label, :placeholder, :description])
  end
end
