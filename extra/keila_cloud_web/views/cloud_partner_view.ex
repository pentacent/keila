require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudPartnerView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use PhoenixHTMLHelpers
    use KeilaWeb.Gettext

    use Phoenix.VerifiedRoutes,
      endpoint: KeilaWeb.Endpoint,
      router: KeilaWeb.Router,
      statics: KeilaWeb.static_paths()

    import Phoenix.Component
    import KeilaWeb.ErrorHelpers
    import KeilaWeb.IconHelper
    import KeilaWeb.PaginationHelpers
  end
end
