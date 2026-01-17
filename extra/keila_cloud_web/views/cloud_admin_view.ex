require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudAdminView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use Phoenix.HTML
    import Phoenix.Component

    import KeilaWeb.Gettext
    alias KeilaWeb.Router.Helpers, as: Routes
  end
end
