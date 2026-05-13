require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Paddle.Transaction do
    @moduledoc """
    Struct representing a transaction (payment) returned by the Paddle Vendor
    API's List Payments endpoint.

    See https://classic.paddle.com/api-specifications/subscription-api.oas2.yml
    """

    defstruct [
      :id,
      :subscription_id,
      :amount,
      :currency,
      :payout_date,
      :is_paid,
      :receipt_url
    ]

    @type t :: %__MODULE__{}

    @types %{
      id: :integer,
      subscription_id: :integer,
      amount: :decimal,
      currency: :string,
      payout_date: :date,
      is_paid: :boolean,
      receipt_url: :string
    }

    @doc """
    Builds a `Transaction` struct from a raw payment object returned by the Paddle API.
    """
    @spec from_api(map()) :: t()
    def from_api(data) when is_map(data) do
      {%__MODULE__{}, @types}
      |> Ecto.Changeset.cast(data, Map.keys(@types))
      |> Ecto.Changeset.apply_changes()
    end
  end
end
