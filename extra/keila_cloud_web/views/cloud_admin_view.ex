require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAdminView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use PhoenixHTMLHelpers
    use KeilaWeb.Gettext
    import Phoenix.Component
    alias KeilaWeb.Router.Helpers, as: Routes
  end
end
