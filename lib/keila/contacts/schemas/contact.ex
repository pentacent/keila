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
  end

  @spec update_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:email, :first_name, :last_name])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end
end
