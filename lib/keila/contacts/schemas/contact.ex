defmodule Keila.Contacts.Contact do
  use Keila.Schema, prefix: "c"
  alias Keila.Contacts.Form

  @statuses Enum.with_index([
              :active,
              :unsubscribed,
              :unreachable
            ])

  schema "contacts" do
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :active)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    timestamps()
  end

  @spec creation_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name, :project_id])
    |> validate_required([:email, :project_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:email, :project_id])
  end

  @spec update_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  @spec changeset_from_form(t(), Ecto.Changeset.data(), Form.t()) :: Ecto.Changeset.t(t())
  def changeset_from_form(struct \\ %__MODULE__{}, params, form) do
    cast_fields =
      form.field_settings
      |> Enum.filter(& &1.cast)
      |> Enum.map(&String.to_existing_atom(&1.field))

    required_fields =
      form.field_settings
      |> Enum.filter(&(&1.cast and &1.required))
      |> Enum.map(&String.to_existing_atom(&1.field))

    struct
    |> cast(params, cast_fields)
    |> validate_dynamic_required(required_fields)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:email, :project_id])
  end

  defp validate_dynamic_required(changeset, required_fields)
  defp validate_dynamic_required(changeset, []), do: changeset
  defp validate_dynamic_required(changeset, fields), do: validate_required(changeset, fields)
end
