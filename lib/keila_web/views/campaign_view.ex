defmodule KeilaWeb.CampaignView do
  use KeilaWeb, :view
  import Ecto.Changeset, only: [get_field: 2]

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
