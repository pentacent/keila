defmodule KeilaWeb.FormView do
  use KeilaWeb, :view
  import KeilaWeb.PublicFormLayoutView, only: [build_styles: 1]
  alias Keila.Mailings.DoubleOptInMessage
  alias Keila.Mailings.WelcomeMessage
end
