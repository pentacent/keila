defmodule Keila.Mailings.MessageActions.Open do
  use Keila.Repo
  import Keila.PipeHelpers
  alias Keila.Mailings.Message

  @doc """
  Runs side-effects associated with a message being opened.

  ## Options
  - `:min_delay` - Minimum delay in seconds since `sent_at` before tracking is recorded.
  """
  @spec handle(Message.id(), Keyword.t()) :: :ok
  def handle(message_id, opts \\ []) do
    min_delay = Keyword.get(opts, :min_delay)

    message_id
    |> maybe_update_message(min_delay)
    |> tap_if_not_nil(&log_event/1)

    :ok
  end

  defp maybe_update_message(message_id, min_delay) do
    query =
      from(r in Message,
        where: r.id == ^message_id and is_nil(r.opened_at),
        select: struct(r, [:id, :contact_id, :campaign_id]),
        update: [set: [opened_at: fragment("now()")]]
      )
      |> maybe_require_min_delay(min_delay)

    Repo.update_one(query, [])
  end

  defp maybe_require_min_delay(query, nil), do: query

  defp maybe_require_min_delay(query, min_delay) when is_integer(min_delay) do
    from(r in query,
      where:
        is_nil(r.sent_at) or
          fragment(
            "? <= (now() - ? * interval '1 second') AT TIME ZONE 'UTC'",
            r.sent_at,
            ^min_delay
          )
    )
  end

  defp log_event(%Message{id: message_id, contact_id: contact_id}) do
    Keila.Tracking.log_event("open", contact_id, message_id, %{})
  end
end
