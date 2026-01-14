defmodule Keila.Mailings.SendDoubleOptInMailWorker do
  @moduledoc """
  Worker for sending double opt-in confirmation emails after form submission.
  """
  require Keila

  use Oban.Worker, queue: :mailer
  use Keila.Repo

  alias Keila.Contacts
  alias Keila.Mailings.DoubleOptInEmailBuilder
  alias Keila.Mailings.RateLimiter
  alias Keila.Mailings.Sender

  @impl true
  def perform(%Oban.Job{args: %{"form_params_id" => form_params_id}}) do
    form_params = Contacts.get_form_params(form_params_id) |> Repo.preload(:form)

    sender = Keila.Mailings.get_sender(form_params.form.sender_id)
    project_id = form_params.form.project_id

    with :ok <- ensure_feature_available(project_id),
         :ok <- ensure_account_active(project_id),
         :ok <- ensure_rate_limit(sender),
         email <- DoubleOptInEmailBuilder.build(form_params) do
      Keila.Mailer.deliver_with_sender(email, sender)
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

  defp ensure_rate_limit(%Sender{} = sender) do
    case RateLimiter.check_sender_rate_limit(sender) do
      :ok ->
        :ok

      {:error, {schedule_at, scheduling_requested_at}} ->
        {:snooze, DateTime.diff(schedule_at, scheduling_requested_at)}
    end
  end

  defp ensure_rate_limit(nil), do: {:cancel, "Sender not found"}
end
