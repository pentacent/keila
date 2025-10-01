defmodule Keila.Mailings.SendDoubleOptInMailWorker do
  alias Keila.Mailings.RateLimiter
  use Oban.Worker, queue: :mailer
  use Keila.Repo
  require Keila

  import KeilaWeb.Gettext

  alias Keila.Contacts
  alias KeilaWeb.Router.Helpers, as: Routes
  alias Swoosh.Email

  @impl true
  def perform(%Oban.Job{args: %{"form_params_id" => form_params_id}}) do
    form_params = Contacts.get_form_params(form_params_id)
    form = Contacts.get_form(form_params.form_id)
    sender = Keila.Mailings.get_sender(form.sender_id)
    project_id = form.project_id

    with :ok <- ensure_feature_available(project_id),
         :ok <- ensure_account_active(project_id),
         :ok <- ensure_rate_limit(sender) do
      send_double_opt_in_email(form_params, form, sender)
    end
  end

  defp ensure_feature_available(project_id) do
    if Keila.Billing.feature_available?(project_id, :double_opt_in) do
      :ok
    else
      {:cancel, "Double opt-in not enabled for account of project #{project_id}"}
    end
  end

  Keila.if_cloud do
    defp ensure_account_active(project_id) do
      case Keila.Accounts.get_project_account(project_id) do
        %{status: :active} -> :ok
        _other -> {:cancel, "Account of project #{project_id} is not active"}
      end
    end
  else
    defp ensure_account_active(_project_id), do: :ok
  end

  defp ensure_rate_limit(sender) do
    case RateLimiter.check_sender_rate_limit(sender) do
      :ok ->
        :ok

      {:error, {schedule_at, scheduling_requested_at}} ->
        {:snooze, DateTime.diff(schedule_at, scheduling_requested_at)}
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

    subject = form.settings.double_opt_in_subject || gettext("Please confirm your email address")

    body_markdown =
      form.settings.double_opt_in_markdown_body ||
        gettext("""
        Please click here to confirm your subscription:

        ### [Confirm subscription]({{ double_opt_in_link }})
        """)

    template =
      if form.template_id,
        do: Keila.Templates.get_template(form.template_id)

    default_styles = Keila.Templates.HybridTemplate.styles()

    styles =
      if template && is_binary(template.styles) do
        Keila.Templates.Css.merge(default_styles, Keila.Templates.Css.parse!(template.styles))
      else
        default_styles
      end

    assigns = %{
      "campaign" => %{"subject" => subject},
      "double_opt_in_link" => double_opt_in_link,
      "unsubscribe_link" => unsubscribe_link,
      "contact" => form_params.params,
      "signature" => if(template, do: template.assigns["signature"])
    }

    Email.new()
    |> Email.from({sender.from_name, sender.from_email})
    |> Email.to(form_params.params["email"])
    |> Email.subject(subject)
    |> Keila.Mailings.Builder.Markdown.put_body(body_markdown, styles, assigns)
    |> Keila.Mailer.deliver_with_sender(sender)
  end
end
