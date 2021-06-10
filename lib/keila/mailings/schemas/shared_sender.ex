defmodule Keila.Mailings.SharedSender do
  use Keila.Schema, prefix: "mss"

  schema "mailings_shared_senders" do
    field :name, :string
    embeds_one(:config, Keila.Mailings.Sender.Config)

    timestamps()
  end

  @spec creation_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t)
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
    |> cast_embed(:config)
    |> apply_constraints()
  end

  @spec update_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
    |> cast_embed(:config)
    |> apply_constraints()
  end

  defp apply_constraints(changeset) do
    changeset
    |> unique_constraint([:name])
  end
end
