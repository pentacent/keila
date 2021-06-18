defmodule Keila.Accounts.Account do
  use Keila.Schema, prefix: "acc"

  schema "accounts" do
    belongs_to(:group, Keila.Auth.Group, type: Keila.Auth.Group.Id)

    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:group_id])
  end
end
