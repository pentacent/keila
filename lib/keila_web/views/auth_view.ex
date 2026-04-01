defmodule KeilaWeb.AuthView do
  use KeilaWeb, :view
  require Keila

  Keila.if_cloud do
    import KeilaCloudWeb.Components.RegistrationCloudData
  end
end
