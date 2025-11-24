require Keila

Keila.if_cloud do
  defmodule KeilaCloud.Workers.SenderDomainVerificationCronWorker do
    @moduledoc """
    Cron worker that runs regularly to find senders with type 'send_with_keila'
    that need domain verification and enqueues verification jobs for them.
    """

    use Oban.Worker, queue: :domain_verification

    import Ecto.Query
    use Keila.Repo
    alias Keila.Mailings.Sender
    alias KeilaCloud.Mailings.SendWithKeila

    @updated_sender_max_age 5 * 24 * 60 * 60
    @updated_sender_check_interval 5 * 60
    @check_interval 5 * 60 * 60

    @impl Oban.Worker
    def perform(_job) do
      get_sender_ids()
      |> Enum.each(&SendWithKeila.verify_domain_async/1)
    end

    defp get_sender_ids() do
      from(s in Sender,
        where: fragment("?->>'type' = ?", s.config, "send_with_keila"),
        where: fragment("(?->>'swk_domain_is_known_shared_domain')::bool IS NOT TRUE", s.config),
        where: ^domain_check_required?(),
        select: s.id
      )
      |> Repo.all()
    end

    defp domain_check_required? do
      now = DateTime.utc_now(:second)
      updated_sender_check_threshold = DateTime.add(now, -@updated_sender_max_age)
      updated_sender_check_interval_threshold = DateTime.add(now, -@updated_sender_check_interval)
      regular_check_interval_threshold = DateTime.add(now, -@check_interval)

      dynamic(
        [s],
        (^domain_not_verified?() and ^sender_updated_after?(updated_sender_check_threshold) and
           ^domain_checked_before?(updated_sender_check_interval_threshold)) or
          ^domain_checked_before?(regular_check_interval_threshold)
      )
    end

    defp domain_not_verified? do
      dynamic([s], is_nil(fragment("?->>'swk_domain_verified_at'", s.config)))
    end

    defp sender_updated_after?(threshold) do
      dynamic([s], s.updated_at > ^threshold)
    end

    defp domain_checked_before?(threshold) do
      dynamic(
        [s],
        is_nil(fragment("?->>'swk_domain_checked_at'", s.config)) or
          fragment("(?->>'swk_domain_checked_at')::timestamptz < ?", s.config, ^threshold)
      )
    end
  end
end
