require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Billing.Plans do
    @moduledoc false

    alias KeilaCloud.Billing.Plan

    if Mix.env() == :prod do
      @plans [
        Plan.new("660926", "XS", 2000, :month, true),
        Plan.new("660927", "S", 5000, :month, true),
        Plan.new("660928", "M", 15000, :month, true),
        Plan.new("660929", "L", 50000, :month, true),
        Plan.new("660930", "XL", 100_000, :month, true),
        Plan.new("660931", "XXL", 250_000, :month, true),
        Plan.new("920819", "XS", 2000, :year, true),
        Plan.new("920820", "S", 5000, :year, true),
        Plan.new("920821", "M", 15000, :year, true),
        Plan.new("920822", "L", 50000, :year, true)
      ]
    else
      @plans [
        Plan.new("13101", "XS", 2000, :month, true),
        Plan.new("13228", "S", 5000, :month, true),
        Plan.new("13229", "M", 15000, :month, true),
        Plan.new("13230", "L", 50000, :month, true),
        Plan.new("13231", "XL", 100_000, :month, true),
        Plan.new("13232", "XXL", 250_000, :month, true),
        Plan.new("86710", "XS", 2000, :year, true)
      ]
    end

    def all() do
      @plans
    end
  end
end
