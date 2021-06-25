defmodule Keila.Billing.Plan do
  defstruct [
    :paddle_id,
    :name,
    :monthly_credits,
    :is_active
  ]

  def new(paddle_id, name, monthly_credits, active?) do
    %__MODULE__{
      paddle_id: paddle_id,
      name: name,
      monthly_credits: monthly_credits,
      is_active: active?
    }
  end
end
