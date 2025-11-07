defmodule Keila.Mailings.Sender do
  use Keila.Schema, prefix: "ms"
  require ExRated

  schema "mailings_senders" do
    field :name, :string
    field :from_email, :string
    field :from_name, :string
    field :reply_to_email, :string
    field :reply_to_name, :string
    field :verified_from_email, :string
    embeds_one(:config, Keila.Mailings.Sender.Config)
    belongs_to(:project, Keila.Projects.Project, type: Keila.Projects.Project.Id)
    belongs_to(:shared_sender, Keila.Mailings.SharedSender, type: Keila.Mailings.SharedSender.Id)

    timestamps()
  end

  @spec creation_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t)
  def creation_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :project_id,
      :name,
      :from_email,
      :from_name,
      :reply_to_email,
      :reply_to_name,
      :shared_sender_id
    ])
    |> validate_required([:project_id, :name, :from_email])
    |> cast_embed(:config)
    |> lowercase_emails()
    |> apply_constraints()
  end

  @spec update_changeset(Ecto.Changeset.data(), map(), Keyword.t()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params, opts \\ []) do
    config_cast_opts =
      opts[:config_cast_opts] || []

    struct
    |> cast(params, [
      :name,
      :from_email,
      :from_name,
      :reply_to_email,
      :reply_to_name,
      :shared_sender_id
    ])
    |> validate_required([:name, :from_email])
    |> cast_embed(:config, config_cast_opts)
    |> maybe_remove_from_email_validation()
    |> lowercase_emails()
    |> apply_constraints()
  end

  defp maybe_remove_from_email_validation(changeset) do
    if changeset.data.verified_from_email != get_field(changeset, :from_email) do
      changeset |> put_change(:verified_from_email, nil)
    else
      changeset
    end
  end

  defp lowercase_emails(changeset) do
    changeset
    |> update_change(:from_email, &downcase_change/1)
    |> update_change(:reply_to_email, &downcase_change/1)
  end

  defp apply_constraints(changeset) do
    changeset
    |> unique_constraint([:from_email])
    |> unique_constraint([:name, :project_id])
  end

  @spec verify_sender_changeset(Ecto.Changeset.data(), String.t()) :: Ecto.Changeset.t(t())
  def verify_sender_changeset(struct \\ %__MODULE__{}, email) do
    struct
    |> cast(%{verified_from_email: email, from_email: email}, [:verified_from_email, :from_email])
    |> validate_required([:verified_from_email, :from_email])
  end

  defp downcase_change(string) when is_binary(string), do: String.downcase(string)
  defp downcase_change(nil), do: nil
end
