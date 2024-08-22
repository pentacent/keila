defmodule Keila.Mailings do
  use Keila.Repo
  alias Keila.Project
  alias __MODULE__.{Sender, SenderAdapters, SharedSender, Campaign, Recipient, RecipientActions}
  alias KeilaWeb.Router.Helpers, as: Routes

  @moduledoc """
  Context for all functionalities related to sending email campaigns.
  """

  @doc """
  Retrieves Sender with given ID.
  """
  @spec get_sender(Sender.id()) :: Sender.t() | nil
  def get_sender(id) when is_id(id),
    do: Repo.one(from(s in Sender, where: s.id == ^id, preload: :shared_sender))

  def get_sender(_),
    do: nil

  @doc """
  Retrieves Sender with given `sender_id` only if it belongs to the specified Project.
  """
  @spec get_project_sender(Project.id(), Sender.id()) :: Sender.t() | nil
  def get_project_sender(project_id, sender_id) do
    from(s in Sender,
      where: s.id == ^sender_id and s.project_id == ^project_id,
      preload: :shared_sender
    )
    |> Repo.one()
  end

  @doc """
  Returns all Senders belonging to specified Project.
  """
  @spec get_project_senders(Project.id()) :: [Sender.t()]
  def get_project_senders(project_id) when is_binary(project_id) or is_integer(project_id) do
    from(s in Sender, where: s.project_id == ^project_id, preload: :shared_sender)
    |> Repo.all()
  end

  @doc """
  Creates a new Sender with given params.
  """
  @spec create_sender(Project.id(), map()) ::
          {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def create_sender(project_id, params) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Sender.creation_changeset()
    |> create_sender_with_callback()
  end

  defp create_sender_with_callback(changeset) do
    transaction_with_rescue(fn ->
      sender = Repo.insert!(changeset) |> Repo.preload(:shared_sender)
      adapter = SenderAdapters.get_adapter(sender.config.type)

      case adapter.after_update(sender) do
        :ok -> sender
        {:error, message} -> changeset |> add_error(:config, message) |> apply_action!(:insert)
      end
    end)
  end

  @doc """
  Updates an existing Sender with given params.
  """
  @spec update_sender(Sender.id(), map()) :: {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def update_sender(id, params) when is_id(id) do
    Repo.get(Sender, id)
    |> Sender.update_changeset(params)
    |> update_sender_with_callback()
  end

  defp update_sender_with_callback(changeset) do
    transaction_with_rescue(fn ->
      sender = Repo.update!(changeset) |> Repo.preload(:shared_sender)
      adapter = SenderAdapters.get_adapter(sender.config.type)

      case adapter.after_update(sender) do
        :ok -> sender
        {:error, message} -> changeset |> add_error(:config, message) |> apply_action!(:update)
      end
    end)
  end

  @doc """
  Deletes Sender with given ID. Associated Campaigns are *not* deleted.

  This function is idempotent and always returns `:ok` unless there is a
  callback error.
  """
  @spec delete_sender(Sender.id()) :: :ok | {:error, term}
  def delete_sender(id) when is_id(id) do
    case Repo.get(Sender, id) do
      nil -> :ok
      sender -> delete_sender_with_callback(sender)
    end
  end

  defp delete_sender_with_callback(sender) do
    adapter = SenderAdapters.get_adapter(sender.config.type)

    case adapter.before_delete(sender) do
      :ok -> Repo.delete(sender) && :ok
      {:error, term} -> {:error, term}
    end
  end

  @doc """
  Verifies sender from `mailings.verify_sender` token.
  """
  @spec verify_sender_from_token(String.t()) :: {:ok, Sender.t()} | {:error, term}
  def verify_sender_from_token(raw_token) do
    case Keila.Auth.find_and_delete_token(raw_token, "mailings.verify_sender") do
      token = %Keila.Auth.Token{} ->
        sender = get_sender(token.data["sender_id"])
        adapter = SenderAdapters.get_adapter(token.data["type"])

        adapter.verify_from_token(sender, token)

      nil ->
        :error
    end
  end

  @doc """
  Retrieves Shared Sender with given `id`.
  """
  @spec get_shared_sender(SharedSender.id()) :: SharedSender.t() | nil
  def get_shared_sender(id) do
    Repo.get(SharedSender, id)
  end

  @doc """
  Retrieves list of all Shared Senders.
  """
  @spec get_shared_senders() :: [SharedSender.t()]
  def get_shared_senders() do
    Repo.all(SharedSender)
  end

  @doc """
  Creates a new Shared Sender.
  """
  @spec create_shared_sender(map()) ::
          {:ok, SharedSender.t()} | {:error, Changeset.t(SharedSender.t())}
  def create_shared_sender(params) do
    params
    |> SharedSender.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates the existing Shared Sender specified by `id`.
  """
  @spec update_shared_sender(SharedSender.id(), map()) ::
          {:ok, SharedSender.t()} | {:error, Changeset.t(SharedSender.t())}
  def update_shared_sender(id, params) when is_id(id) do
    Repo.get(SharedSender, id)
    |> SharedSender.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes a Shared Sender.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_shared_sender(SharedSender.id()) :: :ok
  def delete_shared_sender(id) when is_id(id) do
    from(s in SharedSender, where: s.id == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Retrieves Campaign with given `id`.
  """
  @spec get_campaign(Campaign.id()) :: Campaign.t() | nil
  def get_campaign(id) when is_id(id) do
    Repo.get(Campaign, id, preload: [:template, :segment])
  end

  @doc """
  Retrieves Campaign with given `campaign_id` only if it belongs to the specified Project.
  """
  @spec get_project_campaign(Project.id(), Campaign.id()) :: Campaign.t() | nil
  def get_project_campaign(project_id, campaign_id)
      when is_id(project_id) and is_id(campaign_id) do
    from(c in Campaign,
      where: c.id == ^campaign_id and c.project_id == ^project_id,
      preload: [:template, :segment]
    )
    |> Repo.one()
  end

  @doc """
  Returns all Campaigns belonging to specified Project.
  """
  @spec get_project_campaigns(Project.id()) :: [Campaign.t()]
  def get_project_campaigns(project_id) when is_id(project_id) do
    from(c in Campaign, where: c.project_id == ^project_id, order_by: [desc: c.updated_at])
    |> Repo.all()
  end

  @doc """
  Returns all Campaigns which should have been delivered by `time` but have not yet been delivered.
  """
  @spec get_campaigns_to_be_delivered(DateTime.t()) :: [Campaign.t()]
  def get_campaigns_to_be_delivered(time) do
    from(c in Campaign,
      where: is_nil(c.sent_at) and not is_nil(c.scheduled_for) and c.scheduled_for <= ^time
    )
    |> Repo.all()
  end

  @doc """
  Creates a new Campaign.
  """
  @spec create_campaign(Project.id(), map()) ::
          {:ok, Campaign.t()} | {:error, Changeset.t(Campaign.t())}
  def create_campaign(project_id, params) when is_id(project_id) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Campaign.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates given campaign with `params`.

  If `use_send_changeset?` is set to `true`, a different changeset that
  validates whether campaign is ready to be sent is used.
  """
  @spec update_campaign(Campaign.id(), map(), boolean()) ::
          {:ok, Campaign.t()} | {:error, Changeset.t(Campaign.t())}
  def update_campaign(id, params, use_send_changeset? \\ false)

  def update_campaign(id, params, false) when is_id(id) do
    get_campaign(id)
    |> Campaign.update_changeset(params)
    |> Repo.update()
  end

  def update_campaign(id, params, true) when is_id(id) do
    get_campaign(id)
    |> Campaign.update_and_send_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes given Campaign.

  This function is idempotent and always returns `:ok`
  """
  @spec delete_campaign(Campaign.id()) :: :ok
  def delete_campaign(id) when is_id(id) do
    from(c in Campaign, where: c.id == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes Campaigns with given IDs but only if they belong to Project specified by `project_id`.

  This function is idempotent and always returns `:ok`
  """
  def delete_project_campaigns(project_id, ids) when is_id(project_id) do
    from(c in Campaign, where: c.id in ^ids and c.project_id == ^project_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Duplicates campaign specified by `campaign_id` and optionally applies
  changes given as `params`.
  """
  @spec clone_campaign(Campaign.id(), map()) ::
          {:ok, Campaign.t()} | {:error, Changeset.t(Campaign.t())}
  def clone_campaign(campaign_id, params \\ %{}) when is_id(campaign_id) do
    params =
      params
      |> stringize_params()
      |> Map.drop(["project_id"])

    campaign = get_campaign(campaign_id)
    settings = campaign.settings

    settings_params =
      settings
      |> Map.from_struct()
      |> stringize_params()
      |> Map.merge(params["settings"] || %{})

    campaign
    |> Map.from_struct()
    |> stringize_params()
    |> Map.merge(params)
    |> Map.put("settings", settings_params)
    |> Campaign.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Schedules the given campaign to be delivered in the future.

  Campaigns can be re-scheduled or unscheduled (`%{scheduled_for: nil}`).

  `config :keila, Keila.Mailings, :min_campaign_schedule_offset` determines the
  threshold until when (relative to the current time) a campaign can be
  scheduled, re-scheduled or unscheduled.

  If `:min_campaign_schedule_offset` is set to 60 seconds, campaigns can only be
  scheduled for times at least one minute after the current time.
  Their schedule can  only be modified if there's at least one minute left
  before the campaign was originally scheduled to be delivered.
  """
  @spec schedule_campaign(Campaign.id(), map()) ::
          {:ok, Campaign.t()} | {:error, Changeset.t(Campaign.t())}
  def schedule_campaign(id, params) when is_id(id) do
    get_campaign(id)
    |> Campaign.schedule_changeset(params)
    |> Repo.update()
  end

  @doc """
  Delivers a campaign.

  Returns `:ok`.
  If there were no recipients, returns `{:error, :no_recipients}`
  If no sender is set, returns `{:error, :no_sender}`

  In case of an error, the campaign is un-scheduled if it was previously
  scheduled for sending.
  """
  @spec deliver_campaign(Campaign.id()) :: {:error, :no_recipients} | {:error, term()} | :ok
  def deliver_campaign(id) when is_id(id) do
    result =
      Repo.transaction(
        fn ->
          case get_and_lock_campaign(id) do
            %Campaign{sent_at: sent_at} when not is_nil(sent_at) -> Repo.rollback(:already_sent)
            %Campaign{sender_id: nil} -> Repo.rollback(:no_sender)
            campaign = %Campaign{} -> do_deliver_campaign(campaign)
          end
        end,
        timeout: 60_000
      )

    case result do
      {:ok, _n} ->
        :ok

      {:error, reason} ->
        schedule_campaign(id, %{scheduled_for: nil})
        {:error, reason}
    end
  end

  defp get_and_lock_campaign(id) when is_id(id) do
    from(c in Campaign, where: c.id == ^id, lock: "FOR NO KEY UPDATE", preload: :segment)
    |> Repo.one()
  end

  defp do_deliver_campaign(campaign) do
    {:ok, campaign} =
      campaign
      |> change(sent_at: DateTime.truncate(DateTime.utc_now(), :second))
      |> Repo.update()

    segment_filter = if campaign.segment, do: campaign.segment.filter, else: %{}
    filter = %{"$and" => [segment_filter, %{"status" => "active"}]}

    Keila.Contacts.stream_project_contacts(campaign.project_id, filter: filter)
    |> Stream.chunk_every(5000)
    |> Stream.map(fn contacts ->
      insert_recipients(contacts, campaign)
    end)
    |> Enum.sum()
    |> tap(&maybe_consume_credits(&1, campaign))
    |> tap(&insert_scheduling_job/1)
    |> tap(&ensure_not_empty/1)
  end

  defp insert_recipients(contacts, campaign) do
    {:ok, campaign_id} = Keila.Mailings.Campaign.Id.dump(campaign.id)

    recipient_params =
      Enum.map(contacts, fn contact ->
        {:ok, id} = Keila.Contacts.Contact.Id.dump(contact.id)
        %{id: id}
      end)

    # Inserting entries like this is about 1/3 more performant than constructing structs first
    {count, _} =
      Repo.insert_all(
        Recipient,
        from(r in values(recipient_params, %{id: :integer}),
          select: %{
            contact_id: r.id,
            campaign_id: ^campaign_id,
            inserted_at: fragment("now()"),
            updated_at: fragment("now()")
          }
        )
      )

    count
  end

  defp maybe_consume_credits(recipients_count, _campaign = %{project_id: project_id}) do
    if Keila.Accounts.credits_enabled?() do
      account = Keila.Accounts.get_project_account(project_id)

      if Keila.Accounts.consume_credits(account.id, recipients_count) == :error do
        Repo.rollback(:insufficient_credits)
      end
    end

    :ok
  end

  defp insert_scheduling_job(0), do: :ok
  defp insert_scheduling_job(_), do: Keila.Mailings.ScheduleWorker.new(%{}) |> Oban.insert()

  defp ensure_not_empty(0), do: Repo.rollback(:no_recipients)
  defp ensure_not_empty(_), do: :ok

  @doc """
  Starts the delivery of a campaign as a Task supervised by `Keila.TaskSupervisor`.
  """
  @spec deliver_campaign_async(Campaign.id()) :: DynamicSupervisor.on_start_child()
  def deliver_campaign_async(id) when is_id(id) do
    # TODO: Check if campaign has sender and is valid
    Task.Supervisor.start_child(Keila.TaskSupervisor, __MODULE__, :deliver_campaign, [id])
  end

  @doc """
  Returns map with stats about a campaign.
  """
  @spec get_campaign_stats(Campaign.id()) :: %{
          status: :insufficient_credits | :unsent | :preparing | :sending | :sent,
          recipients_count: non_neg_integer(),
          sent_count: non_neg_integer(),
          open_count: non_neg_integer(),
          click_count: non_neg_integer(),
          failed_count: non_neg_integer(),
          unsubscribe_count: non_neg_integer(),
          hard_bounce_count: non_neg_integer(),
          complaint_count: non_neg_integer(),
          clicked_at_series: list({hour :: non_neg_integer(), count :: non_neg_integer()}),
          opened_at_series: list({hour :: non_neg_integer(), count :: non_neg_integer()})
        }
  def get_campaign_stats(campaign_id) when is_id(campaign_id) do
    campaign = get_campaign(campaign_id)
    recipient_stats = recipient_stats(campaign.id)

    time_series_end = if campaign.sent_at, do: campaign.sent_at |> DateTime.add(24, :hour)

    opened_at_series =
      recipient_time_series(campaign.id, :opened_at, campaign.sent_at, time_series_end)

    clicked_at_series =
      recipient_time_series(campaign.id, :clicked_at, campaign.sent_at, time_series_end)

    insufficient_credits? =
      if Keila.Accounts.credits_enabled?() do
        account = Keila.Accounts.get_project_account(campaign.project_id)

        contacts_count =
          Keila.Contacts.get_project_contacts_count(campaign.project_id,
            filter: %{"status" => "active"}
          )

        not Keila.Accounts.has_credits?(account.id, contacts_count)
      end

    recipients_count = recipient_stats[:recipients_count] - recipient_stats[:failed_count]

    locked? =
      !Repo.exists?(
        from(c in Campaign, where: c.id == ^campaign_id, lock: "FOR UPDATE SKIP LOCKED")
      )

    status =
      cond do
        is_nil(campaign.sent_at) and insufficient_credits? -> :insufficient_credits
        locked? and recipients_count == 0 -> :preparing
        is_nil(campaign.sent_at) -> :unsent
        recipient_stats[:sent_count] != recipients_count -> :sending
        recipient_stats[:sent_count] == recipients_count -> :sent
      end

    recipient_stats
    |> Map.put(:status, status)
    |> Map.put(:opened_at_series, opened_at_series)
    |> Map.put(:clicked_at_series, clicked_at_series)
  end

  defp recipient_stats(campaign_id) do
    from(r in Recipient, where: r.campaign_id == ^campaign_id)
    |> where([r], r.campaign_id == ^campaign_id)
    |> select(
      [r],
      %{
        recipients_count: count(),
        sent_count: sum(fragment("CASE WHEN sent_at IS NOT NULL THEN 1 ELSE 0 END")),
        open_count: sum(fragment("CASE WHEN opened_at IS NOT NULL THEN 1 ELSE 0 END")),
        click_count: sum(fragment("CASE WHEN clicked_at IS NOT NULL THEN 1 ELSE 0 END")),
        failed_count: sum(fragment("CASE WHEN failed_at IS NOT NULL THEN 1 ELSE 0 END")),
        unsubscribe_count:
          sum(fragment("CASE WHEN unsubscribed_at IS NOT NULL THEN 1 ELSE 0 END")),
        hard_bounce_count:
          sum(fragment("CASE WHEN hard_bounce_received_at IS NOT NULL THEN 1 ELSE 0 END")),
        complaint_count:
          sum(fragment("CASE WHEN complaint_received_at IS NOT NULL THEN 1 ELSE 0 END"))
      }
    )
    |> Repo.one()
    |> Enum.map(fn
      {key, nil} -> {key, 0}
      {key, value} -> {key, value}
    end)
    |> Enum.into(%{})
  end

  defp recipient_time_series(_campaign_id, _field, nil = _start_time, _end_time), do: []

  defp recipient_time_series(campaign_id, field, start_time, end_time) do
    from(
      r in Recipient,
      right_join:
        series in fragment(
          "select generate_series(date_trunc('hour', ?::timestamp), date_trunc('hour', ?::timestamp), '1h') as h",
          ^start_time,
          ^end_time
        ),
      on:
        series.h == fragment("date_trunc('hour', ?)", field(r, ^field)) and
          r.campaign_id == ^campaign_id and not is_nil(field(r, ^field)),
      group_by: series.h,
      order_by: series.h,
      select: {series.h, count(r.id)}
    )
    |> Repo.all()
  end

  @doc """
  Retrieves a Recipient with Contact preloaded.
  """
  @spec get_recipient(Recipient.id()) :: Recipient.t() | nil
  def get_recipient(recipient_id) do
    from(r in Recipient,
      where: r.id == ^recipient_id,
      preload: [:contact]
    )
    |> Repo.one()
  end

  @doc """
  Returns a signed unsubscribe link for the given project id and recipient.
  """
  @spec get_unsubscribe_link(Project.id(), Recipient.id()) :: String.t()
  def get_unsubscribe_link(project_id, recipient_id) do
    hmac = unsubscribe_hmac(project_id, recipient_id)

    Routes.public_form_url(KeilaWeb.Endpoint, :unsubscribe, project_id, recipient_id, hmac)
  end

  @doc """
  Returns `true` if project id and recipient id evaluate to the given HMAC.
  Else returns `false`
  """
  @spec valid_unsubscribe_hmac?(Project.id(), Recipient.id(), String.t()) :: boolean()
  def valid_unsubscribe_hmac?(project_id, recipient_id, hmac) do
    case unsubscribe_hmac(project_id, recipient_id) do
      ^hmac -> true
      _other -> false
    end
  end

  defp unsubscribe_hmac(project_id, recipient_id) do
    key = Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.fetch!(:secret_key_base)
    message = "unsubscribe:" <> project_id <> ":" <> recipient_id

    :crypto.mac(:hmac, :sha256, key, message)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Unsubscribes the contact associated with a recipient from a project and logs
  the event.
  """
  @spec unsubscribe_recipient(Recipient.id()) :: :ok
  def unsubscribe_recipient(recipient_id) do
    RecipientActions.Unsubscription.handle(recipient_id)
  end

  @doc """
  Updates a recipient after they opened an email in a campaign for the first
  time and logs the event.
  """
  @spec handle_recipient_open(Recipient.id()) :: :ok
  def handle_recipient_open(recipient_id) do
    RecipientActions.Open.handle(recipient_id)
  end

  @doc """
  Updates a recipient after they clicked a link in a campaign for the first time
  and logs the event.
  """
  @spec handle_recipient_click(Recipient.id()) :: :ok
  def handle_recipient_click(recipient_id) do
    RecipientActions.Click.handle(recipient_id)
  end

  @doc """
  Unsubscribes a recipient after a complaint was received and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_recipient_complaint(Recipient.id(), map()) :: :ok
  def handle_recipient_complaint(recipient_id, data) do
    RecipientActions.Complaint.handle(recipient_id, data)
  end

  @doc """
  Handles a soft bounce for a recipient and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_recipient_soft_bounce(Recipient.id(), map()) :: :ok
  def handle_recipient_soft_bounce(recipient_id, data) do
    RecipientActions.SoftBounce.handle(recipient_id, data)
  end

  @doc """
  Marks the contact associated with a recipient as unreachable after receiving
  hard bounce and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_recipient_hard_bounce(Recipient.id(), map()) :: :ok
  def handle_recipient_hard_bounce(recipient_id, data) do
    RecipientActions.HardBounce.handle(recipient_id, data)
  end
end
