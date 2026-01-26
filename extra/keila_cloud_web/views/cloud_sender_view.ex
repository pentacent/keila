require Keila

Keila.if_cloud do
  defmodule KeilaWeb.CloudSenderView do
    use Phoenix.View,
      root: "extra/keila_cloud_web/templates",
      namespace: KeilaWeb

    use PhoenixHTMLHelpers
    import Phoenix.HTML.Form, only: [input_id: 3]
    use KeilaWeb.Gettext
    import Phoenix.Component
    import KeilaWeb.ErrorHelpers
    import KeilaWeb.IconHelper
  end
end
