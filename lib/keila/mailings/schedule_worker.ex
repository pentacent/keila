defmodule Keila.Mailings.ScheduleWorker do
  @moduledoc """
  This worker inserts email delivery jobs for recipients.

  The worker is run once a minute and inserts jobs in serveral small batches
  per run to make sure jobs are available right after having been scheduled.
  """

  use Oban.Worker,
    queue: :periodic,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing]
    ]

  use Keila.Repo

  require Logger

  alias Keila.Mailings
  alias Keila.Mailings.Campaign
  alias Keila.Mailings.Sender
  alias Keila.Mailings.Recipient

  @limit 250
  @passes 12
  @threshold @limit * @passes

  @impl true
  def perform(%Oban.Job{}) do
    Enum.reduce_while(1..@passes, :ok, fn _, _ ->
      Repo.transaction(fn ->
        if jobs_below_threshold?() do
          schedule_recipients()
          {:cont, :ok}
        else
          {:halt, :ok}
        end
      end)
    end)
  end

  defp jobs_below_threshold?() do
    existing_jobs =
      from(j in Oban.Job,
        where: j.queue == "mailer" and j.state in ["available", "executing"],
        limit: @threshold
      )
      |> Repo.aggregate(:count, :id)

    existing_jobs <= @threshold
  end

  defp schedule_recipients() do
    from(r in Recipient,
      where: is_nil(r.queued_at) and is_nil(r.failed_at),
      select: %{id: r.id, campaign_id: r.campaign_id},
      limit: @limit,
      lock: "FOR NO KEY UPDATE"
    )
    |> Enum.group_by(& &1.campaign_id)
    |> Enum.each(fn {campaign_id, recipients} ->
      insert_jobs(campaign_id, recipients)
    end)
  end

  defp insert_jobs(campaign_id, recipients) do
    with campaign = %Campaign{} <- Mailings.get_campaign(campaign_id),
         sender = %Sender{} <- Mailings.get_sender(campaign.sender_id) do
      do_insert_jobs(sender, recipients)
      mark_recipients_as_queued(recipients)
    else
      _ -> mark_recipients_as_failed(recipients)
    end
  end

  defp do_insert_jobs(sender, recipients) do
    job_params =
      Enum.map(recipients, fn recipient ->
        {schedule_at, scheduling_requested_at} =
          Keila.Mailings.RateLimiter.get_sender_schedule_at(sender)

        %{
          args: %{
            "recipient_id" => recipient.id,
            "scheduling_requested_at" => scheduling_requested_at
          },
          scheduled_at: schedule_at
        }
      end)

    default = Keila.Mailings.Worker.new(%{}) |> Ecto.Changeset.apply_action!(:insert)

    Repo.insert_all(
      Oban.Job,
      from(j in values(job_params, %{args: :map, scheduled_at: :utc_datetime}),
        select: %{
          args: j.args,
          scheduled_at: j.scheduled_at,
          state: "scheduled",
          queue: ^default.queue,
          worker: ^default.worker,
          attempt: ^default.attempt,
          max_attempts: ^default.max_attempts,
          inserted_at: fragment("now()")
        }
      )
    )
  end

  defp mark_recipients_as_queued(recipients) do
    ids = Enum.map(recipients, & &1.id)

    from(r in Recipient,
      where: r.id in ^ids,
      update: [set: [queued_at: fragment("now()"), updated_at: fragment("now()")]]
    )
    |> Repo.update_all([])

    n = length(recipients)
    campaign_id = get_in(recipients, [Access.at(0), Access.key(:campaign_id)])
    Logger.info("Queued #{n} job(s) for campaign #{campaign_id}")
  end

  defp mark_recipients_as_failed(recipients) do
    ids = Enum.map(recipients, & &1.id)

    from(r in Recipient,
      where: r.id in ^ids,
      update: [
        set: [
          failed_at: fragment("now()"),
          queued_at: fragment("now()"),
          updated_at: fragment("now()")
        ]
      ]
    )
    |> Repo.update_all([])

    n = length(recipients)
    campaign_id = get_in(recipients, [Access.at(0), Access.key(:campaign_id)])
    Logger.info("Failed to queue #{n} job(s) for campaign #{campaign_id}")
  end
end
