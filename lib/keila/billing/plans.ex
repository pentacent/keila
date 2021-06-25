defmodule Keila.Billing.Plans do
  @moduledoc false

  alias Keila.Billing.Plan

  if Mix.env() == :prod do
    @plans [
      Plan.new("660926", "XS", 2000, true),
      Plan.new("660927", "S", 5000, true),
      Plan.new("660928", "M", 15000, true),
      Plan.new("660929", "L", 50000, true),
      Plan.new("660930", "XL", 100_000, true),
      Plan.new("660931", "XXL", 250_000, true)
    ]
  else
    @plans [
      Plan.new("13101", "XS", 2000, true),
      Plan.new("13228", "S", 5000, true),
      Plan.new("13229", "M", 15000, true),
      Plan.new("13230", "L", 50000, true),
      Plan.new("13231", "XL", 100_000, true),
      Plan.new("13232", "XXL", 250_000, true)
    ]
  end

  def all() do
    @plans
  end
end
