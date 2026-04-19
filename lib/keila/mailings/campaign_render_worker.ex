defmodule Keila.Mailings.CampaignRenderWorker do
  @moduledoc """
  Oban worker that renders campaign messages in batches.

  When a campaign is sent, all messages are inserted with `status: :unrendered`.
  This worker fetches a batch of unrendered messages for a given campaign,
  renders each one using `Builder.build/3`, and updates them to `status: :ready`.

  If there are more unrendered messages remaining after the batch, the worker
  re-enqueues itself to process the next batch.
  """

  use Oban.Worker,
    queue: :campaign_renderer,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :retryable],
      keys: [:campaign_id]
    ]

  use Keila.Repo
  require Logger
  alias Keila.Mailings.Message
  alias Keila.Mailings.Builder

  @batch_size 500
  @render_timeout 1_000

  @impl true
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    campaign = Keila.Mailings.get_campaign(campaign_id)

    if is_nil(campaign) do
      {:cancel, :campaign_not_found}
    else
      render_messages(campaign)
    end
  end

  defp render_messages(campaign) do
    from(m in Message,
      where: m.campaign_id == ^campaign.id and m.status == :unrendered,
      left_join: c in assoc(m, :contact),
      select: %{m | contact: c},
      limit: @batch_size
    )
    |> Repo.all()
    |> async_render_messages(campaign)
    |> tap(&update_rendered_messages/1)
    |> tap(&update_failed_messages/1)
    |> tap(fn results ->
      unless length(results) < @batch_size do
        Oban.insert!(new(%{"campaign_id" => campaign.id}))
      end
    end)

    :ok
  end

  defp async_render_messages(messages, campaign) do
    messages
    |> Task.async_stream(&render_message(&1, campaign),
      timeout: @render_timeout,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Enum.map(fn
      {:ok, result} ->
        result

      {:exit, {message, :timeout}} ->
        Logger.warning("CampaignRenderWorker: render timeout for message #{message.id}")
        {:message, :error}
    end)
  end

  defp render_message(message, campaign) do
    with email = Builder.build(campaign, message, %{}),
         :ok <- ensure_valid_email(email),
         [{_, _}] <- email.to do
      {message, {:ok, email}}
    else
      {:error, :rendering_error} ->
        {message, :error}

      other ->
        Logger.warning("CampaignRenderWorker: unexpected error: #{inspect(other)}")
        {message, :error}
    end
  rescue
    e ->
      Logger.error(
        "CampaignRenderWorker: exception rendering message #{message.id}: #{Exception.message(e)}"
      )

      {message, :error}
  end

  @message_update_types %{
    message_id: Message.Id,
    subject: :string,
    html_body: :string,
    text_body: :string,
    recipient_email: :string,
    recipient_name: :string
  }

  defp update_rendered_messages(results) do
    message_updates =
      results
      |> Enum.filter(fn {_message, result} -> match?({:ok, _}, result) end)
      |> Enum.map(fn {message, {:ok, email}} ->
        [{recipient_name, recipient_email}] = email.to

        %{
          message_id: message.id,
          subject: email.subject,
          html_body: email.html_body,
          text_body: email.text_body,
          recipient_email: recipient_email,
          recipient_name: recipient_name
        }
      end)

    if Enum.any?(message_updates) do
      from(m in Message,
        join: mu in values(message_updates, @message_update_types),
        on: m.id == mu.message_id,
        where: m.status == :unrendered,
        update: [
          set: [
            status: :ready,
            subject: mu.subject,
            html_body: mu.html_body,
            text_body: mu.text_body,
            recipient_email: mu.recipient_email,
            recipient_name: mu.recipient_name,
            updated_at: fragment("NOW()")
          ]
        ]
      )
      |> Repo.update_all([])
    end
  end

  defp update_failed_messages(results) do
    message_ids =
      results
      |> Enum.filter(fn {_message, result} -> result == :error end)
      |> Enum.map(fn {message, _} -> message.id end)

    if Enum.any?(message_ids) do
      from(m in Message,
        where: m.id in ^message_ids and m.status == :unrendered,
        update: [
          set: [status: :failed, failed_at: fragment("NOW()"), updated_at: fragment("NOW()")]
        ]
      )
      |> Repo.update_all([])
    end
  end

  defp ensure_valid_email(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      {:error, :rendering_error}
    else
      :ok
    end
  end
end
