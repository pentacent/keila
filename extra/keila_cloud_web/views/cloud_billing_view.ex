require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudBillingView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use PhoenixHTMLHelpers
    use KeilaWeb.Gettext

    use Phoenix.VerifiedRoutes,
      endpoint: KeilaWeb.Endpoint,
      router: KeilaWeb.Router,
      statics: KeilaWeb.static_paths()

    import KeilaWeb.DateTimeHelpers, only: [local_date_tag: 1]
    import KeilaWeb.PaginationHelpers
  end
end
