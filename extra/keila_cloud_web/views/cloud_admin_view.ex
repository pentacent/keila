defmodule KeilaWeb.CloudAdminView do
  use Phoenix.View,
    root: "extra/keila_cloud_web/templates",
    namespace: KeilaWeb

  use Phoenix.HTML
  import Phoenix.View
  import Phoenix.LiveView.Helpers

  import KeilaWeb.Gettext
  import KeilaWeb.ErrorHelpers
  alias KeilaWeb.Router.Helpers, as: Routes
end
