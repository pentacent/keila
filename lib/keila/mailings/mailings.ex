defmodule Keila.Mailings do
  require Keila
  use Keila.Repo
  alias Keila.Project
  alias __MODULE__.{Sender, SenderAdapters, SharedSender, Campaign, Message, MessageActions}
  alias KeilaWeb.Router.Helpers, as: Routes
  require Logger

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
          {:ok, Sender.t()} | {:action_required, Sender.t()} | {:error, Changeset.t(Sender.t())}
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

      verification_required? = adapter.requires_verification?()

      if verification_required? do
        send_sender_verification_email(sender.id)
      end

      case adapter.after_create(sender) do
        :ok -> if verification_required?, do: {:action_required, sender}, else: sender
        {:action_required, sender} -> {:action_required, sender}
        {:error, message} -> changeset |> add_error(:config, message) |> apply_action!(:insert)
      end
    end)
    |> unwrap_transaction_result()
  end

  defp unwrap_transaction_result({:ok, sender = %Sender{}}), do: {:ok, sender}

  defp unwrap_transaction_result({:ok, {:action_required, sender = %Sender{}}}),
    do: {:action_required, sender}

  defp unwrap_transaction_result({:error, changeset}), do: {:error, changeset}

  @doc """
  Returns the Sender from line in the form of `"Name <test@example.com>"`
  If the Sender uses a Send with Keila proxy address, the Reply-to email is printed instead.
  """
  @spec sender_from_line(Sender.t()) :: String.t()
  def sender_from_line(sender) do
    email =
      if String.ends_with?(sender.from_email, "@mailings.keilausercontent.com") do
        sender.reply_to_email
      else
        sender.from_email
      end

    name = sender.from_name || sender.reply_to_name

    if name do
      "#{name} <#{email}>"
    else
      email
    end
  end

  @doc """
  Updates an existing Sender with given params.

  When a Sender is updated, this is broadcast via `Phoenix.PubSub` on the channel `"sender:%sender_id%"`

  ## Options
  - `:config_cast_opts` (optional) - Options passed to the `cast_embed` function of the config field.
  - `:skip_callback` (optional) - If true, the adapter `after_update` callback will not be called.
  """
  @spec update_sender(Sender.id(), map()) :: {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def update_sender(id, params, opts \\ []) when is_id(id) do
    sender = Repo.get(Sender, id)
    adapter = SenderAdapters.get_adapter(sender.config.type)

    sender
    |> Sender.update_changeset(params, opts)
    |> adapter.update_changeset()
    |> update_sender_with_callback(opts)
    |> unwrap_transaction_result()
    |> tap(&maybe_send_update_message/1)
  end

  defp update_sender_with_callback(changeset, opts) do
    transaction_with_rescue(fn ->
      sender = Repo.update!(changeset) |> Repo.preload(:shared_sender)
      adapter = SenderAdapters.get_adapter(sender.config.type)

      from_email_changed? =
        changed?(changeset, :from_email) and
          get_change(changeset, :from_email) != changeset.data.from_email and
          get_change(changeset, :from_email) != changeset.data.verified_from_email

      verification_required? = from_email_changed? and adapter.requires_verification?()

      if verification_required? do
        send_sender_verification_email(sender.id)
      end

      skip_callback? = opts[:skip_callback] || false
      callback_response = if skip_callback?, do: :ok, else: adapter.after_update(sender)

      case callback_response do
        :ok ->
          if verification_required? do
            {:action_required, sender}
          else
            sender
          end

        {:action_required, updated_sender} ->
          {:action_required, updated_sender}

        {:error, message} ->
          changeset |> add_error(:config, message) |> apply_action!(:update)
      end
    end)
  end

  defp maybe_send_update_message({ok_or_action_required, updated_sender})
       when ok_or_action_required in [:ok, :action_required] do
    Phoenix.PubSub.broadcast(
      Keila.PubSub,
      "sender:#{updated_sender.id}",
      {:sender_updated, updated_sender}
    )
  end

  defp maybe_send_update_message(_), do: :ok

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
  Sends a verification email to the sender with the given ID.
  """
  @spec send_sender_verification_email(Sender.id(), (String.t() -> String.t())) :: :ok
  def send_sender_verification_email(id, url_fn \\ &default_url_function/1) do
    sender = get_sender(id)
    adapter = SenderAdapters.get_adapter(sender.config.type)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(3 * 24, :hour)
      |> DateTime.truncate(:second)

    {:ok, token} =
      Keila.Auth.create_token(%{
        scope: "mailings.verify_sender",
        user_id: nil,
        data: %{email: sender.from_email, sender_id: sender.id},
        expires_at: expires_at
      })

    if function_exported?(adapter, :deliver_verification_email, 3) do
      adapter.deliver_verification_email(sender, token.key, url_fn)
    else
      Keila.Auth.Emails.send!(:verify_sender_from_email, %{
        sender: sender,
        url: url_fn.(token.key)
      })
    end
  end

  defp default_url_function(token) do
    KeilaWeb.Router.Helpers.sender_url(KeilaWeb.Endpoint, :verify_from_token, token)
  end

  @doc """
  Verifies sender from `mailings.verify_sender` token.
  """
  @spec verify_sender_from_email(String.t()) :: {:ok, Sender.t()} | {:error, term}
  def verify_sender_from_email(raw_token) do
    with token = %Keila.Auth.Token{} <- find_and_delete_verification_token(raw_token),
         sender_id when is_binary(sender_id) <- token.data["sender_id"],
         email when is_binary(email) <- token.data["email"],
         sender = %Sender{} <- get_sender(sender_id) do
      sender
      |> Sender.verify_sender_changeset(email)
      |> Repo.update()
      |> tap(&maybe_run_after_from_email_verification_callbacks/1)
      |> tap(&maybe_send_update_message/1)
    else
      _ -> :error
    end
  end

  defp maybe_run_after_from_email_verification_callbacks({:ok, sender}) do
    adapter = SenderAdapters.get_adapter(sender.config.type)

    if function_exported?(adapter, :after_from_email_verification, 1) do
      adapter.after_from_email_verification(sender)
    end

    adapter.after_update(sender)
  end

  defp maybe_run_after_from_email_verification_callbacks(_), do: :ok

  @doc """
  Cancels a sender verification by deleting the verification token.
  This function is idempotent and always returns `:ok`.
  """
  @spec cancel_sender_from_email_verification(String.t()) :: :ok
  def cancel_sender_from_email_verification(raw_token) do
    with token = %Keila.Auth.Token{} <- find_and_delete_verification_token(raw_token),
         sender = %Sender{} <- get_sender(token.data["sender_id"]),
         adapter = SenderAdapters.get_adapter(sender.config.type),
         true <- function_exported?(adapter, :after_from_email_verification, 1) do
      adapter.after_from_email_verification(sender)
    else
      _ -> :ok
    end
  end

  defp find_and_delete_verification_token(raw_token) do
    Keila.Auth.find_and_delete_token(raw_token, "mailings.verify_sender")
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
  Returns all Campaigns belonging to the specified Project.
  """
  @spec get_project_campaigns(Project.id()) :: [Campaign.t()]
  def get_project_campaigns(project_id) when is_id(project_id) do
    from(c in Campaign, where: c.project_id == ^project_id, order_by: [desc: c.updated_at])
    |> Repo.all()
  end

  @doc """
  Returns the latest Campaign belonging to the specified Project.
  """
  @spec get_latest_project_campaign(Project.id()) :: Campaign.t() | nil
  def get_latest_project_campaign(project_id) when is_id(project_id) do
    from(c in Campaign,
      where: c.project_id == ^project_id,
      order_by: [desc: c.inserted_at],
      limit: 1
    )
    |> Repo.one()
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

  @doc """
  Searches for campaigns in a given project that contain the given search string.

  Returns a list of campaigns that match the search string or an empty list if no campaigns match.

  The search string is matched against the `text_body`, `html_body`, `mjml_body`, and `json_body` fields.
  """
  @spec search_in_project_campaigns(Project.id(), String.t()) :: [Campaign.t()]
  def search_in_project_campaigns(project_id, search_string)
      when is_binary(project_id) or is_integer(project_id) do
    from(c in Campaign,
      where: c.project_id == ^project_id,
      where:
        fragment(
          "text_body LIKE ? OR html_body LIKE ? OR mjml_body LIKE ? OR json_body::text LIKE ?",
          ^"%#{search_string}%",
          ^"%#{search_string}%",
          ^"%#{search_string}%",
          ^"%#{search_string}%"
        ),
      order_by: [desc: :updated_at]
    )
    |> Repo.all()
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
      insert_messages(contacts, campaign)
    end)
    |> Enum.sum()
    |> tap(&maybe_consume_credits(&1, campaign))
    |> tap(&insert_rendering_job(&1, campaign))
    |> tap(&ensure_not_empty/1)
  end

  @unrendered_status Ecto.Enum.mappings(Message, :status)[:unrendered]
  defp insert_messages(contacts, campaign) do
    {:ok, campaign_id} = Keila.Mailings.Campaign.Id.dump(campaign.id)
    {:ok, sender_id} = Keila.Mailings.Sender.Id.dump(campaign.sender_id)
    Logger.info("Inserting messages for campaign #{campaign_id} with sender #{sender_id}")

    # Inserting entries like this is about 1/3 more performant than constructing structs first
    contact_ids =
      Enum.map(contacts, fn contact ->
        {:ok, id} = Keila.Contacts.Contact.Id.dump(contact.id)
        %{id: id}
      end)

    {count, _} =
      Repo.insert_all(
        Message,
        from(c in values(contact_ids, %{id: :integer}),
          select: %{
            contact_id: c.id,
            campaign_id: ^campaign_id,
            sender_id: ^sender_id,
            inserted_at: fragment("now()"),
            updated_at: fragment("now()"),
            status: @unrendered_status
          }
        )
      )

    count
  end

  defp maybe_consume_credits(messages_count, _campaign = %{project_id: project_id}) do
    if Keila.Accounts.credits_enabled?() do
      account = Keila.Accounts.get_project_account(project_id)

      Keila.if_cloud do
        if account.status != :active do
          Repo.rollback(:account_not_active)
        end
      end

      if Keila.Accounts.consume_credits(account.id, messages_count) == :error do
        Repo.rollback(:insufficient_credits)
      end
    end

    :ok
  end

  defp insert_rendering_job(0, _campaign), do: :ok

  defp insert_rendering_job(_, campaign),
    do: Keila.Mailings.CampaignRenderWorker.new(%{"campaign_id" => campaign.id}) |> Oban.insert!()

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
          status:
            :insufficient_credits | :account_not_active | :unsent | :preparing | :sending | :sent,
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
    account = Keila.Accounts.get_project_account(campaign.project_id)

    time_series_end = if campaign.sent_at, do: campaign.sent_at |> DateTime.add(24, :hour)

    opened_at_series =
      message_time_series(campaign.id, :opened_at, campaign.sent_at, time_series_end)

    clicked_at_series =
      message_time_series(campaign.id, :clicked_at, campaign.sent_at, time_series_end)

    insufficient_credits? =
      if Keila.Accounts.credits_enabled?() do
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

    Keila.if_cloud do
      status =
        if is_nil(campaign.sent_at) and account.status == :onboarding_required,
          do: :account_not_active,
          else: status
    end

    recipient_stats
    |> Map.put(:status, status)
    |> Map.put(:opened_at_series, opened_at_series)
    |> Map.put(:clicked_at_series, clicked_at_series)
  end

  defp recipient_stats(campaign_id) do
    from(m in Message, where: m.campaign_id == ^campaign_id)
    |> select(
      [m],
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

  defp message_time_series(_campaign_id, _field, nil = _start_time, _end_time), do: []

  defp message_time_series(campaign_id, field, start_time, end_time) do
    from(
      m in Message,
      right_join:
        series in fragment(
          "select generate_series(date_trunc('hour', ?::timestamp), date_trunc('hour', ?::timestamp), '1h') as h",
          ^start_time,
          ^end_time
        ),
      on:
        series.h == fragment("date_trunc('hour', ?)", field(m, ^field)) and
          m.campaign_id == ^campaign_id and not is_nil(field(m, ^field)),
      group_by: series.h,
      order_by: series.h,
      select: {series.h, count(m.id)}
    )
    |> Repo.all()
  end

  @doc """
  Retrieves a Message with Contact preloaded.
  """
  @spec get_message(Message.id()) :: Message.t() | nil
  def get_message(message_id) do
    from(r in Message,
      where: r.id == ^message_id,
      preload: [:contact]
    )
    |> Repo.one()
  end

  @doc """
  Returns a signed unsubscribe link for the given project id and message.
  """
  @spec get_unsubscribe_link(Project.id(), Message.id()) :: String.t()
  def get_unsubscribe_link(project_id, message_id) do
    hmac = unsubscribe_hmac(project_id, message_id)

    Routes.public_form_url(KeilaWeb.Endpoint, :unsubscribe, project_id, message_id, hmac)
  end

  @doc """
  Returns `true` if project id and message id evaluate to the given HMAC.
  Else returns `false`
  """
  @spec valid_unsubscribe_hmac?(Project.id(), Message.id(), String.t()) :: boolean()
  def valid_unsubscribe_hmac?(project_id, message_id, hmac) do
    case unsubscribe_hmac(project_id, message_id) do
      ^hmac -> true
      _other -> false
    end
  end

  defp unsubscribe_hmac(project_id, message_id) do
    key = Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.fetch!(:secret_key_base)
    message = "unsubscribe:" <> project_id <> ":" <> message_id

    :crypto.mac(:hmac, :sha256, key, message)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Unsubscribes the contact associated with a message from a project and logs
  the event.
  """
  @spec unsubscribe_from_message(Message.id()) :: :ok
  def unsubscribe_from_message(message_id) do
    MessageActions.Unsubscription.handle(message_id)
  end

  @doc """
  Updates a message it was opened for the first time and logs the event.
  """
  @spec handle_message_open(Message.id(), Keyword.t()) :: :ok
  def handle_message_open(message_id, opts \\ []) do
    MessageActions.Open.handle(message_id, opts)
  end

  @doc """
  Updates a message after a link in it was clicked for the first time
  and logs the event.
  """
  @spec handle_message_click(Message.id(), Keyword.t()) :: :ok
  def handle_message_click(message_id, opts \\ []) do
    MessageActions.Click.handle(message_id, opts)
  end

  @doc """
  Unsubscribes a message after a complaint was received and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_message_complaint(Message.id(), map()) :: :ok
  def handle_message_complaint(message_id, data) do
    MessageActions.Complaint.handle(message_id, data)
  end

  @doc """
  Handles a soft bounce for a message and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_message_soft_bounce(Message.id(), map()) :: :ok
  def handle_message_soft_bounce(message_id, data) do
    MessageActions.SoftBounce.handle(message_id, data)
  end

  @doc """
  Marks the contact associated with a message as unreachable after receiving
  hard bounce and logs the event.
  The `data` parameter is passed to the logging system.
  """
  @spec handle_message_hard_bounce(Message.id(), map()) :: :ok
  def handle_message_hard_bounce(message_id, data) do
    MessageActions.HardBounce.handle(message_id, data)
  end

  @doc """
  Enables or disables the public link for a campaign.

  Returns the updated campaign.
  """
  @spec enable_public_link!(campaign_id :: Campaign.id(), enable? :: boolean()) :: Campaign.t()
  def enable_public_link!(campaign_id, enable? \\ true) do
    campaign_id
    |> get_campaign()
    |> Ecto.Changeset.change(%{public_link_enabled: enable?})
    |> Repo.update!()
  end

  @doc """
  Retrieves a public campaign by its ID.

  Returns the campaign if it exists, has `public_link_enabled` set to true, and been sent. Otherwise returns `nil`.
  """
  @spec get_public_campaign(campaign_id :: Campaign.id()) :: Campaign.t() | nil
  def get_public_campaign(campaign_id) do
    from(c in Campaign,
      where: c.id == ^campaign_id and c.public_link_enabled == true and not is_nil(c.sent_at),
      preload: [:template]
    )
    |> Repo.one()
  end

  @doc """
  Returns the public campaign link URL for a given campaign ID.

  This is just a convenience function and doesn't actually check whether the
  public link is enabled for the given campaign.
  """
  @spec get_public_campaign_link(campaign_id :: Campaign.id()) :: String.t()
  def get_public_campaign_link(campaign_id) do
    Routes.public_campaign_url(KeilaWeb.Endpoint, :show, campaign_id)
  end

  @doc """
  Prunes `html_body` and `text_body` from messages with status `:sent` or
  `:failed` if they are older than the pruning threshold.

  Prunes at most 1000 messages by default unless a different limit is specified.

  The threshold can be configured via the `MESSAGE_RETENTION_DAYS` environment
  variable.
  """
  @spec prune_messages(limit :: non_neg_integer() | :infinity) :: {non_neg_integer(), nil}
  def prune_messages(limit \\ :infinity) do
    retention_days =
      Application.get_env(:keila, __MODULE__) |> Keyword.fetch!(:message_retention_days)

    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

    from(m in Keila.Mailings.Message,
      where:
        m.id in subquery(
          from(m in Message,
            where: m.status in [:sent, :failed],
            where: m.inserted_at < ^cutoff,
            where: not is_nil(m.html_body) or not is_nil(m.text_body),
            select: m.id
          )
          |> then(fn query ->
            case limit do
              limit when is_integer(limit) -> limit(query, ^limit)
              _ -> query
            end
          end)
        )
    )
    |> Repo.update_all(set: [html_body: nil, text_body: nil])
  end
end
