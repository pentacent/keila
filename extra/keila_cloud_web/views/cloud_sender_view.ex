require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudSenderView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use Phoenix.HTML
    import Phoenix.Component
    import KeilaWeb.Gettext
    import KeilaWeb.ErrorHelpers
    import KeilaWeb.IconHelper
  end
end
