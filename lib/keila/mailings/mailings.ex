defmodule Keila.Mailings do
  use Keila.Repo
  alias Keila.Project
  alias __MODULE__.{Sender, Campaign, Recipient}

  @moduledoc """
  Context for all functionalities related to sending email campaigns.
  """

  @spec get_sender(Sender.id()) :: Sender.t() | nil
  def get_sender(id) when is_id(id),
    do: Repo.get(Sender, id)

  def get_sender(_),
    do: nil

  @spec get_project_sender(Project.id(), Sender.id()) :: Sender.t() | nil
  def get_project_sender(project_id, sender_id) do
    from(s in Sender, where: s.id == ^sender_id and s.project_id == ^project_id)
    |> Repo.one()
  end

  @spec get_project_senders(Project.id()) :: [Project.t()]
  def get_project_senders(project_id) when is_binary(project_id) or is_integer(project_id) do
    from(s in Sender, where: s.project_id == ^project_id)
    |> Repo.all()
  end

  @spec create_sender(Project.id(), map()) ::
          {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def create_sender(project_id, params) do
    params
    |> stringize_params()
    |> Map.put("project_id", project_id)
    |> Sender.creation_changeset()
    |> Repo.insert()
  end

  @spec update_sender(Sender.id(), map()) :: {:ok, Sender.t()} | {:error, Changeset.t(Sender.t())}
  def update_sender(id, params) when is_id(id) do
    Repo.get(Sender, id)
    |> Sender.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Deletes Sender with given ID. Associated Campaigns are *not* deleted.

  This function is idempotent and always returns `:ok`.
  """
  @spec delete_sender(Sender.id()) :: :ok
  def delete_sender(id) when is_id(id) do
    from(s in Sender, where: s.id == ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Retrieves Campaign with given `id`.
  """
  @spec get_campaign(Campaign.id()) :: Campaign.t() | nil
  def get_campaign(id) when is_id(id) do
    Repo.get(Campaign, id)
  end

  @doc """
  Retrieves Campaign with given `campaign_id` only if it belongs to the specified Project.
  """
  @spec get_project_campaign(Project.id(), Campaign.id()) :: Campaign.t() | nil
  def get_project_campaign(project_id, campaign_id)
      when is_id(project_id) and is_id(campaign_id) do
    from(c in Campaign, where: c.id == ^campaign_id and c.project_id == ^project_id)
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
  Updates given campaign with `params`
  """
  @spec update_campaign(Campaign.id(), map()) ::
          {:ok, Campaign.t()} | {:error, Changeset.t(Campaign.t())}
  def update_campaign(id, params) when is_id(id) do
    get_campaign(id)
    |> Campaign.update_changeset(params)
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
  Delivers a campaign.

  Returns `:ok`.
  If there were no recipients, returns `{:error, :no_recipients}`
  """
  @spec deliver_campaign(Campaign.id()) :: {:error, :no_recipients} | {:error, term()} | :ok
  def deliver_campaign(id) when is_id(id) do
    {:ok, campaign} =
      id
      |> get_campaign()
      |> change(sent_at: DateTime.truncate(DateTime.utc_now(), :second))
      |> Repo.update()

    stream = Keila.Contacts.stream_project_contacts(campaign.project_id, [])

    case do_deliver_campaign(stream, campaign) do
      {:ok, :ok} ->
        :ok

      {:error, reason} ->
        campaign
        |> change(sent_at: nil)
        |> Repo.update()

        {:error, reason}
    end
  end

  defp do_deliver_campaign(contacts_stream, campaign) do
    Repo.transaction(fn ->
      contacts_stream
      |> Enum.map(fn contact ->
        now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()
        %{contact_id: contact.id, campaign_id: campaign.id, inserted_at: now, updated_at: now}
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn recipients ->
        {_n, recipients} = Repo.insert_all(Recipient, recipients, returning: [:id])
        recipients
      end)
      |> Stream.map(fn recipients ->
        recipients
        |> Enum.map(fn recipient ->
          Keila.Mailings.Worker.new(%{"recipient_id" => recipient.id})
        end)
        |> Oban.insert_all()
      end)
      |> run_or_rollback()
    end)
  end

  defp run_or_rollback(stream) do
    case Enum.count(stream) do
      0 -> Repo.rollback(:no_recipients)
      n -> :ok
    end
  end

  @doc """
  Starts the delivery of a campaign as a Task supervised by `Keila.TaskSupervisor`.
  """
  @spec deliver_campaign_async(Campaign.id()) :: DynamicSupervisor.on_start_child()
  def deliver_campaign_async(id) when is_id(id) do
    Task.Supervisor.start_child(Keila.TaskSupervisor, __MODULE__, :deliver_campaign, [id])
  end

  def get_campaign_stats(campaign_id) when is_id(campaign_id) do
    campaign = get_campaign(campaign_id)

    {recipients_count, sent_count} =
      from(r in Recipient, where: r.campaign_id == ^campaign_id)
      |> where([r], r.campaign_id == ^campaign_id)
      |> select([r], {count(), sum(fragment("CASE WHEN sent_at IS NOT NULL THEN 1 ELSE 0 END"))})
      |> Repo.one()

    sent_count = sent_count || 0

    status =
      cond do
        is_nil(campaign.sent_at) -> :unsent
        not is_nil(campaign.sent_at) and recipients_count == 0 -> :preparing
        recipients_count != sent_count -> :sending
        recipients_count == sent_count -> :sent
      end

    %{
      status: status,
      recipients_count: recipients_count,
      sent_count: sent_count
    }
  end
end
