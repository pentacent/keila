defmodule KeilaWeb.SenderView do
  use KeilaWeb, :view

  def sender_adapters do
    Keila.Mailings.SenderAdapters.adapter_names()
  end

  def sender_adapter_name("smtp"), do: "SMTP"
  def sender_adapter_name("ses"), do: "SES"
  def sender_adapter_name("sendgrid"), do: "Sendgrid"
  def sender_adapter_name("mailgun"), do: "Mailgun"

  if Mix.env() == :test do
    def sender_adapter_name("test"), do: "Test"
  end

  if Mix.env() == :dev do
    def sender_adapter_name("local"), do: "Local"
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
end
