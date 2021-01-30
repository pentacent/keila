defmodule KeilaWeb.CampaignView do
  use KeilaWeb, :view

  def delete_form(conn, project_id, id) do
    route = Routes.campaign_path(conn, :delete, project_id)

    form_for(:campaign, route, [id: "delete-form-#{id}", method: "delete"], fn f ->
      [
        hidden_input(f, :require_confirmation, value: "true"),
        hidden_input(f, :id, value: id)
      ]
    end)
  end
end
