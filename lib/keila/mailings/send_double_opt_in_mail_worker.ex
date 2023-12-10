defmodule Keila.Mailings.SendDoubleOptInMailWorker do
  use Oban.Worker, queue: :mailer
  use Keila.Repo

  import KeilaWeb.Gettext

  alias Keila.Contacts
  alias KeilaWeb.Router.Helpers, as: Routes
  alias Swoosh.Email

  @impl true
  def perform(%Oban.Job{args: %{"form_params_id" => form_params_id}}) do
    form_params = Contacts.get_form_params(form_params_id)
    form = Contacts.get_form(form_params.form_id)
    sender = Keila.Mailings.get_sender(form.sender_id)

    case Keila.Mailer.check_sender_rate_limit(sender) do
      :ok -> send_double_opt_in_email(form_params, form, sender)
      {:error, min_delay} -> {:snooze, min_delay + 5}
    end
  end

  defp send_double_opt_in_email(form_params, form, sender) do
    hmac = Contacts.double_opt_in_hmac(form_params.form_id, form_params.id)

    double_opt_in_link =
      Routes.public_form_url(KeilaWeb.Endpoint, :double_opt_in, form.id, form_params.id, hmac)

    unsubscribe_link =
      Routes.public_form_url(
        KeilaWeb.Endpoint,
        :cancel_double_opt_in,
        form.id,
        form_params.id,
        hmac
      )

    subject = gettext("Please confirm your email address")

    body_markdown =
      gettext("""
      Please click here to confirm your subscription:

      ### [Confirm subscription]({{ double_opt_in_link }})
      """)

    template =
      if form.template_id,
        do: Keila.Templates.get_template(form.template_id)

    default_styles = Keila.Templates.HybridTemplate.styles()

    styles =
      if template do
        Keila.Templates.Css.merge(default_styles, template.styles)
      else
        default_styles
      end

    assigns = %{
      "double_opt_in_link" => double_opt_in_link,
      "unsubscribe_link" => unsubscribe_link
    }

    Email.new()
    |> Email.from({sender.from_name, sender.from_email})
    |> Email.to(form_params.params["email"])
    |> Email.subject(subject)
    |> Keila.Mailings.Builder.Markdown.put_body(body_markdown, styles, assigns)
    |> Keila.Mailer.deliver_with_sender(sender)
  end
end