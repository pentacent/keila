defmodule Keila.Billing.Subscription do
  use Keila.Schema, prefix: "bsub"

  @insert_fields [:paddle_subscription_id, :paddle_user_id, :account_id]
  @update_fields [:paddle_plan_id, :update_url, :cancel_url, :next_billed_on, :status]

  schema "billing_subscriptions" do
    field :paddle_subscription_id, :string
    field :paddle_plan_id, :string
    field :paddle_user_id, :string
    field :update_url, :string
    field :cancel_url, :string

    field :next_billed_on, :date
    field :status, Ecto.Enum, values: [active: 1, trialing: 2, past_due: 3, paused: 4, deleted: 5]

    belongs_to(:account, Keila.Accounts.Account, type: Keila.Accounts.Account.Id)

    timestamps()
  end

  @spec insert_changeset(t(), Ecto.Changeset.data()) :: Ecto.Changeset.t(t())
  def insert_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @insert_fields ++ @update_fields)
    |> validate()
  end

  def update_changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @update_fields)
    |> validate()
  end

  defp validate(changeset) do
    changeset
    |> validate_required(@insert_fields ++ @update_fields)
    |> unique_constraint(:account_id)
    |> unique_constraint(:paddle_subscription_id)
  end
end
