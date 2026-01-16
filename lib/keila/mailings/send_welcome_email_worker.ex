defmodule Keila.Mailings.SendWelcomeEmailWorker do
  @moduledoc """
  Worker for sending welcome emails after successful signup.
  """

  require Keila

  use Oban.Worker, queue: :mailer
  use Keila.Repo

  alias Keila.Contacts
  alias Keila.Mailings.RateLimiter
  alias Keila.Mailings.WelcomeEmailBuilder

  @impl true
  def perform(%Oban.Job{args: %{"contact_id" => contact_id, "form_id" => form_id}}) do
    contact = Contacts.get_contact(contact_id)
    form = Contacts.get_form(form_id)
    sender = Keila.Mailings.get_sender(form.sender_id)
    project_id = form.project_id

    with :ok <- ensure_feature_available(project_id),
         :ok <- ensure_account_active(project_id),
         :ok <- ensure_welcome_enabled(form),
         :ok <- ensure_rate_limit(sender),
         email <- WelcomeEmailBuilder.build(contact, form) do
      Keila.Mailer.deliver_with_sender(email, sender)
    end
  end

  defp ensure_feature_available(project_id) do
    if Keila.Billing.feature_available?(project_id, :welcome_email) do
      :ok
    else
      {:cancel, "Welcome email not enabled for account of project #{project_id}"}
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

  defp ensure_welcome_enabled(form) do
    if form.settings.welcome_enabled do
      :ok
    else
      {:cancel, "Welcome email not enabled for form #{form.id}"}
    end
  end

  defp ensure_rate_limit(sender) do
    case RateLimiter.check_sender_rate_limit(sender) do
      :ok ->
        :ok

      {:error, {schedule_at, scheduling_requested_at}} ->
        {:snooze, DateTime.diff(schedule_at, scheduling_requested_at)}
    end
  end
end
