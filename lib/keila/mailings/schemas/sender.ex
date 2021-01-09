defmodule Keila.Mailings.Sender do
  use Keila.Schema, prefix: "ms"

  schema "mailings_senders" do
    field :name, :string
    field :from_email, :string
    field :from_name, :string
    field :reply_to_email, :string
    field :reply_to_name, :string
    embeds_one(:config, Keila.Mailings.Sender.Config)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)

    timestamps()
  end

  @spec creation_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t)
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:project_id, :name, :from_email, :from_name, :reply_to_email, :reply_to_name])
    |> validate_required([:project_id, :name, :from_email])
    |> cast_embed(:config)
    |> lowercase_emails()
    |> apply_constraints()
  end

  @spec update_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :from_email, :from_name, :reply_to_email, :reply_to_name])
    |> validate_required([:name, :from_email])
    |> cast_embed(:config)
    |> lowercase_emails()
    |> apply_constraints()
  end

  defp lowercase_emails(changeset) do
    changeset
    |> update_change(:from_email, &String.downcase/1)
    |> update_change(:reply_to_email, &String.downcase/1)
  end

  defp apply_constraints(changeset) do
    changeset
    |> unique_constraint([:from_email])
    |> unique_constraint([:name, :project_id])
  end
end
