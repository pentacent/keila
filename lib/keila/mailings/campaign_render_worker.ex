defmodule Keila.Mailings.CampaignRenderWorker do
  @moduledoc """
  Oban worker that renders campaign messages in batches.

  When a campaign is sent, all messages are inserted with `status: :unrendered`.
  This worker fetches a batch of unrendered messages for a given campaign,
  renders each one using `Builder.build/3`, and updates them to `status: :ready`.

  If there are more unrendered messages remaining after the batch, the worker
  re-enqueues itself to process the next batch.
  """

  use Oban.Worker, queue: :campaign_renderer
  use Keila.Repo
  require Logger
  alias Keila.Mailings.Message
  alias Keila.Mailings.Builder

  @batch_size 500

  @impl true
  def perform(%Oban.Job{args: %{"campaign_id" => campaign_id}}) do
    campaign = Keila.Mailings.get_campaign(campaign_id)

    from(m in Message,
      where: m.campaign_id == ^campaign_id and m.status == :unrendered,
      left_join: c in assoc(m, :contact),
      select: %{m | contact: c},
      limit: @batch_size
    )
    |> Repo.all()
    |> Enum.map(&render_and_save_message(&1, campaign))
    |> then(fn updated_messages ->
      if length(updated_messages) == @batch_size do
        %{"campaign_id" => campaign_id}
        |> __MODULE__.new()
        |> Oban.insert()
      end
    end)

    :ok
  end

  defp render_and_save_message(message, campaign) do
    with email = Builder.build(campaign, message, %{}),
         :ok <- ensure_valid_email(email),
         [{recipient_name, recipient_email}] <- email.to do
      update_message(message, %{
        status: :ready,
        subject: email.subject,
        text_body: email.text_body,
        html_body: email.html_body,
        recipient_email: recipient_email,
        recipient_name: recipient_name
      })
    else
      {:error, :rendering_error} ->
        update_message(message, %{status: :failed, failed_at: DateTime.utc_now()})

      other ->
        Logger.warning("CampaignRenderWorker: unexpected error: #{inspect(other)}")
        update_message(message, %{status: :failed, failed_at: DateTime.utc_now()})
    end
  end

  defp update_message(message, params) do
    message
    |> Message.changeset(params)
    |> Repo.update()
  end

  defp ensure_valid_email(email) do
    if Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end) do
      {:error, :rendering_error}
    else
      :ok
    end
  end
end
