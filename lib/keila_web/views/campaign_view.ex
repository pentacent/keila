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

  def plain_text_preview(text) do
    """
    <!doctype html>
    <html>
      <head><meta charset="utf-8"/></head>
      <body style="margin: 0; padding: 20px; background: #eee; font-family: mono;;">
        <div style="max-width: 80ch; margin: 0 auto; padding: 20px;background: white; white-space: pre-line">
    #{text}
        </div>
      </body>
    </html>
    """
  end
end
