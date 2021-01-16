defmodule Keila.Contacts.Contact do
  use Keila.Schema, prefix: "c"

  schema "contacts" do
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
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

  @spec dynamic_changeset(t(), Ecto.Changeset.data(), Keyword.t()) :: Ecto.Changeset.t(t())
  def dynamic_changeset(struct \\ %__MODULE__{}, params, opts) do
    required_fields = Keyword.get(opts, :required, [])
    cast_fields = ([:email | Keyword.get(opts, :cast, [])] ++ required_fields) |> Enum.uniq()

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
