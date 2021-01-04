defmodule Keila.Auth.Group do
  use Keila.Schema, prefix: "ag"

  schema "groups" do
    field(:name, :string)
    belongs_to(:parent, __MODULE__, foreign_key: :parent_id, references: :id, type: __MODULE__.Id)
    has_many(:children, __MODULE__, foreign_key: :parent_id, references: :id)

    timestamps()
  end

  @spec creation_changeset(Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :parent_id])
    |> validate_required([:parent_id])
    |> foreign_key_constraint(:parent_id)
  end

  @spec update_changeset(Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :parent_id])
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint([:parent_id], name: "root_group")
  end

  @doc """
  Returns an Ecto Query for the group with the given `id` and all its
  descendant groups.
  """
  @spec with_children(integer) :: Ecto.Query.t()
  def with_children(id) do
    init = where(__MODULE__, [g], g.id == ^id)
    recursion = join(__MODULE__, :inner, [g], sg in "children", on: g.parent_id == sg.id)
    cte = union(init, ^recursion)

    from("children")
    |> recursive_ctes(true)
    |> with_cte("children", as: ^cte)
    |> select([g], %__MODULE__{id: g.id, parent_id: g.parent_id})
  end

  @doc """
  Returns an Ecto Query for the group with no parent.

  Use with `Repo.one!`.
  """
  @spec root_query() :: Ecto.Query.t()
  def root_query() do
    from(g in __MODULE__, where: is_nil(g.parent_id))
  end
end
