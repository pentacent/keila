defmodule Keila.Accounts.Account do
  require Keila
  use Keila.Schema, prefix: "acc"

  schema "accounts" do
    belongs_to(:parent, __MODULE__, type: __MODULE__.Id)
    belongs_to(:group, Keila.Auth.Group, type: Keila.Auth.Group.Id)

    Keila.if_cloud do
      use KeilaCloud.Accounts.Account
    end

    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:group_id])
  end
end
