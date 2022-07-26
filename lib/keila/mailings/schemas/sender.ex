defmodule Keila.Mailings.Sender do
  use Keila.Schema, prefix: "ms"
  require ExRated

  schema "mailings_senders" do
    field :name, :string
    field :from_email, :string
    field :from_name, :string
    field :reply_to_email, :string
    field :reply_to_name, :string
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

  @spec update_changeset(Ecto.Changeset.data(), map()) :: Ecto.Changeset.t(t())
  def update_changeset(struct \\ %__MODULE__{}, params) do
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
    |> cast_embed(:config)
    |> lowercase_emails()
    |> apply_constraints()
  end

  @spec check_rate(%__MODULE__{}) :: {:error, integer} | {:ok, integer}
  def check_rate(struct) do
    with {:ok, hour_calls} <-
           ExRated.check_rate(
             "sender-bucket-per-hour-#{struct.id}",
             3_600_000,
             struct.config.rate_limit_per_hour
           ),
         {:ok, minute_calls} <-
           ExRated.check_rate(
             "sender-bucket-per-minute-#{struct.id}",
             60_000,
             struct.config.rate_limit_per_minute
           ),
         {:ok, second_calls} <-
           ExRated.check_rate(
             "sender-bucket-per-second-#{struct.id}",
             1_000,
             struct.config.rate_limit_per_second
           ) do
      {:ok, hour_calls + minute_calls + second_calls}
    else
      {:error, calls} -> {:error, calls}
    end
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
