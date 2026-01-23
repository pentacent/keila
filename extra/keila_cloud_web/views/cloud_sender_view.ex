require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudSenderView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use PhoenixHTMLHelpers
    use KeilaWeb.Gettext
    import Phoenix.Component
    import KeilaWeb.ErrorHelpers
    import KeilaWeb.IconHelper
  end
end
