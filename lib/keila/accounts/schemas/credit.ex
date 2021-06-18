defmodule Keila.Accounts.CreditTransaction do
  use Keila.Schema, prefix: "acc"

  schema "accounts_credit_transactions" do
    field :amount, :integer
    field :expires_at, :utc_datetime

    belongs_to(:account, Keila.Accounts.Account, type: Keila.Accounts.Account.Id)

    timestamps(updated_at: false)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount, :expires_at, :account_id])
  end
end
