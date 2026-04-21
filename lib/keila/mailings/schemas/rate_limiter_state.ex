defmodule Keila.Mailings.RateLimiterState do
  use Keila.Schema, manual_id: true

  schema "rate_limiter_state" do
    field :data, :binary
    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:id, :data])
    |> validate_required([:id, :data])
    |> check_constraint(:id, name: :singleton)
  end
end
