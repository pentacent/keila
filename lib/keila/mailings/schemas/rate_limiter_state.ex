defmodule Keila.Mailings.RateLimiterState do
  use Keila.Schema

  schema "rate_limiter_state" do
    field :data, :binary
    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:data])
    |> validate_required([:data])
  end
end
