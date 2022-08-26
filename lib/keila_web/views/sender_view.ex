defmodule KeilaWeb.SenderView do
  use KeilaWeb, :view
  alias KeilaWeb.Endpoint

  def meta("index.html", :title, _assigns), do: gettext("Senders")

  def meta("edit.html", :title, %{sender: sender}) when not is_nil(sender),
    do: gettext("Edit Sender %{sender}", sender: sender.name)

  def meta("edit.html", :title, _assigns), do: gettext("New Sender")

  def meta("delete.html", :title, %{sender: sender}) when not is_nil(sender),
    do: gettext("Delete Sender %{sender}?", sender: sender.name)

  def meta(_template, _key, _assigns), do: nil

  defp form_path(%{id: project_id}, %{data: %{id: nil}}),
    do: Routes.sender_path(Endpoint, :create, project_id)

  defp form_path(%{id: project_id}, %{data: %{id: id}}),
    do: Routes.sender_path(Endpoint, :update, project_id, id)

  def sender_adapters do
    if Application.get_env(:keila, :sender_creation_disabled) do
      []
    else
      Keila.Mailings.SenderAdapters.adapter_names()
    end
  end

  def sender_adapter_name("smtp"), do: "SMTP"
  def sender_adapter_name("ses"), do: "SES"
  def sender_adapter_name("sendgrid"), do: "Sendgrid"
  def sender_adapter_name("mailgun"), do: "Mailgun"
  def sender_adapter_name("shared_ses"), do: "Shared SES"

  if Mix.env() == :test do
    def sender_adapter_name("test"), do: "Test"
  end

  if Mix.env() == :dev do
    def sender_adapter_name("local"), do: "Local"
    def sender_adapter_name("shared_local"), do: "Shared Local"
  end

  def render_sender_adapter_form(form, "smtp") do
    render("_smtp_config.html", form: form)
  end

  def render_sender_adapter_form(form, "ses") do
    render("_ses_config.html", form: form)
  end

  def render_sender_adapter_form(form, "sendgrid") do
    render("_sendgrid_config.html", form: form)
  end

  def render_sender_adapter_form(form, "mailgun") do
    render("_mailgun_config.html", form: form)
  end

  if Mix.env() == :test do
    def render_sender_adapter_form(_form, "test"), do: nil
  end

  if Mix.env() == :dev do
    def render_sender_adapter_form(form, "local") do
      render("_local_config.html", form: form)
    end
  end

  def render_shared_sender_adapter_form(form, "ses") do
    render("_shared_ses_config.html", form: form)
  end

  if Mix.env() == :dev do
    def render_shared_sender_adapter_form(form, "local") do
      render("_shared_local_config.html", form: form)
    end
  end
end
