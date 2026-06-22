defmodule KeilaWeb.ApiMessageView do
  use KeilaWeb, :view

  def render("message.json", %{message: message}) do
    %{
      "data" => %{
        "id" => message.id,
        "recipient_email" => message.recipient_email,
        "subject" => message.subject
      }
    }
  end

  def render("renderer_output.json", %{output: output}) do
    %{
      "data" => %{
        "subject" => output.subject,
        "html_body" => output.html_body,
        "text_body" => output.text_body
      }
    }
  end
end
