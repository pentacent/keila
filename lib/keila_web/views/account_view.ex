defmodule KeilaWeb.AccountView do
  require Keila
  use KeilaWeb, :view

  Keila.if_cloud do
    import KeilaCloud.Components.SubscriptionStatus
  end
end
