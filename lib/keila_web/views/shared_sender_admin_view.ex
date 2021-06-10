defmodule KeilaWeb.SharedSenderAdminView do
  use KeilaWeb, :view
  alias KeilaWeb.Endpoint

  defp form_path(%{data: %{id: nil}}),
    do: Routes.shared_sender_admin_path(Endpoint, :create)

  defp form_path(%{data: %{id: id}}),
    do: Routes.shared_sender_admin_path(Endpoint, :update, id)
end
