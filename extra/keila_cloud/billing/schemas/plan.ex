require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.Plan do
    defstruct [
      :paddle_id,
      :name,
      :monthly_credits,
      :is_active,
      :billing_interval
    ]

    def new(paddle_id, name, monthly_credits, billing_interval, active?) do
      %__MODULE__{
        paddle_id: paddle_id,
        name: name,
        monthly_credits: monthly_credits,
        billing_interval: billing_interval,
        is_active: active?
      }
    end
  end
end
