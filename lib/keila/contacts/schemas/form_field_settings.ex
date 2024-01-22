defmodule Keila.Contacts.Form.FieldSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [:email, :first_name, :last_name, :data]
  @types [:email, :string, :integer, :boolean, :enum, :tags, :array]

  embedded_schema do
    field(:field, Ecto.Enum, values: @fields)
    field(:required, :boolean)
    field(:cast, :boolean)
    field(:key, :string)
    field(:type, Ecto.Enum, values: @types)
    field(:label, :string)
    field(:placeholder, :string)
    field(:description, :string)

    embeds_many :allowed_values, __MODULE__.AllowedValue, on_replace: :delete
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :id,
      :field,
      :key,
      :required,
      :type,
      :cast,
      :label,
      :placeholder,
      :description
    ])
    |> cast_embed(:allowed_values)
    |> maybe_validate_key()
  end

  defp maybe_validate_key(changeset) do
    if get_field(changeset, :field) == :data do
      changeset
      |> validate_required(:key)
      |> validate_format(:key, ~r/^[a-zA-Z_]+$/)
    else
      changeset
    end
  end
end

defmodule Keila.Contacts.Form.FieldSettings.AllowedValue do
  use Ecto.Schema
  use Keila.Repo

  embedded_schema do
    field :label, :string
    field :value, :string
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:label, :value])
  end
end
