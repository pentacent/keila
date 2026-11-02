defmodule Keila.Contacts.Segment do
  use Keila.Schema, prefix: "sgm"

  schema "contacts_segments" do
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    field(:name, :string)

    field(:filter, :map)

    timestamps()
  end

  @spec creation_changeset(t(), Changeset.data()) :: Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :project_id, :filter])
    |> ensure_filter_not_empty()
    |> validate_filter()
  end

  @spec update_changeset(t(), Changeset.data()) :: Changeset.t(t())
  def update_changeset(struct, params) do
    struct
    |> cast(params, [:name, :filter])
    |> validate_required(:name)
    |> ensure_filter_not_empty()
    |> validate_filter()
  end

  defp validate_filter(changeset) do
    validate_change(changeset, :filter, fn :filter, filter ->
      if Keila.Contacts.Query.valid_opts?(filter: filter),
        do: [],
        else: [filter: "is not a valid filter"]
    end)
  end

  defp ensure_filter_not_empty(changeset) do
    case get_field(changeset, :filter) do
      nil -> put_change(changeset, :filter, %{})
      _other -> changeset
    end
  end
end
