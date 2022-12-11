defmodule Keila.Tracking do
  @moduledoc """
  Module for tracking events, currently `open` and `click` events from Mailings.
  """

  use Keila.Repo
  alias __MODULE__.{Link, Click}
  alias Keila.Mailings.{Campaign, Recipient}
  alias KeilaWeb.Router.Helpers, as: Routes

  @doc """
  Registers a new `Link` with given `url` for `Campaign` specified by
  `campaign_id`.
  """
  @spec register_link(String.t(), Campaign.id()) :: Link.t()
  def register_link(url, campaign_id) do
    Link.changeset(%{url: url, campaign_id: campaign_id})
    |> Repo.insert!()
  end

  @doc """
  Retrieves existing `Link` with given `url` from `Campaign` specified by
  `campaign_id`. If it doesn’t yet exist, creates and returns new `Link`.
  """
  @spec get_or_register_link(String.t(), Campaign.id()) :: Link.t()
  def get_or_register_link(url, campaign_id) do
    case find_link_by_url(url, campaign_id) do
      nil -> register_link(url, campaign_id)
      link -> link
    end
  end

  @doc """
  Retrieves existing `Link` with given `id`.
  """
  @spec get_link(Link.id()) :: Link.t() | nil
  def get_link(id) do
    Repo.get(Link, id)
  end

  @doc """
  Retrieves `Link` with given `url` from `Campaign` specified by `campaign_id`.
  """
  @spec find_link_by_url(String.t(), Campaign.id()) :: Link.t() | nil
  def find_link_by_url(url, campaign_id) do
    from(l in Link, where: l.url == ^url and l.campaign_id == ^campaign_id)
    |> Repo.one()
  end

  @doc """
  Returns URL for given parameters.

  ## `:click` URLs
  Returns hmac-signed URL for tracking `click` events and registers a `Link`.

  ## `:open` URLs
  Returns hmac-signed URL for tracking `:open` events without registering a
  `Link`.
  """
  def get_tracking_url(conn, :click, %{
        campaign_id: campaign_id,
        recipient_id: recipient_id,
        url: url
      }) do
    {encoded_url, link_id, hmac} = tracking_path_params(:click, campaign_id, recipient_id, url)

    Routes.tracking_url(conn, :track_click, encoded_url, recipient_id, link_id, hmac)
  end

  def get_tracking_url(conn, :open, %{
        campaign_id: campaign_id,
        recipient_id: recipient_id,
        url: url
      }) do
    {encoded_url, hmac} = tracking_path_params(:open, campaign_id, recipient_id, url)

    Routes.tracking_url(conn, :track_open, encoded_url, recipient_id, hmac)
  end

  @doc """
  Returns paths for given parameters.

  ## `:click` paths
  Returns hmac-signed path for tracking `click` events and registers a `Link`.

  ## `:open` paths
  Returns hmac-signed path for tracking `:open` events without registering a
  `Link`.
  """
  def get_tracking_path(conn, :click, %{
        campaign_id: campaign_id,
        recipient_id: recipient_id,
        url: url
      }) do
    {encoded_url, link_id, hmac} = tracking_path_params(:click, campaign_id, recipient_id, url)

    Routes.tracking_path(conn, :track_click, encoded_url, recipient_id, link_id, hmac)
  end

  def get_tracking_path(conn, :open, %{
        campaign_id: campaign_id,
        recipient_id: recipient_id,
        url: url
      }) do
    {encoded_url, hmac} = tracking_path_params(:open, campaign_id, recipient_id, url)

    Routes.tracking_path(conn, :track_open, encoded_url, recipient_id, hmac)
  end

  defp tracking_path_params(:click, campaign_id, recipient_id, url) do
    encoded_url = URI.encode_www_form(url)
    %Link{id: link_id} = get_or_register_link(url, campaign_id)
    hmac = create_hmac(encoded_url, recipient_id, link_id)

    {encoded_url, link_id, hmac}
  end

  defp tracking_path_params(:open, _campaign_id, recipient_id, url) do
    encoded_url = URI.encode_www_form(url)
    hmac = create_hmac(encoded_url, recipient_id)

    {encoded_url, hmac}
  end

  @doc """
  Tracks an event.

  ## `:open` event
  - Required params: `:encoded_url`, `:recipient_id`, `:hmac`, `:user_agent`

  Returns: `{:ok, url}` if  hmac verification was successful, otherwise `:error`.

  ## `:click` event
  - Required params: `:encoded_url`, `:recipient_id`, `:hmac`
  - Optional params: `link_id`

  Returns: `{:ok, url}` if  hmac verification was successful, otherwise `:error`.
  """
  @spec track(:click | :open, map()) :: {:ok, term()} | :error
  def track(:click, %{
        encoded_url: encoded_url,
        recipient_id: recipient_id,
        link_id: link_id,
        hmac: hmac
      }) do
    case verify_hmac(hmac, encoded_url, recipient_id, link_id) do
      :ok ->
        track_click(recipient_id, link_id)
        set_recipient_clicked_at(recipient_id)

        {:ok, URI.decode_www_form(encoded_url)}

      :error ->
        :error
    end
  end

  def track(:open, %{
        encoded_url: encoded_url,
        recipient_id: recipient_id,
        hmac: hmac,
        user_agent: user_agent
      }) do
    case verify_hmac(hmac, encoded_url, recipient_id) do
      :ok ->
        unless is_user_agent_bot(user_agent) do
          set_recipient_opened_at(recipient_id)
        end

        {:ok, URI.decode_www_form(encoded_url)}

      :error ->
        :error
    end
  end

  defp track_click(_recipient_id, nil), do: :ok

  defp track_click(recipient_id, link_id) do
    Click.changeset(%{recipient_id: recipient_id, link_id: link_id})
    |> Repo.insert!()
  end

  defp set_recipient_clicked_at(recipient_id, now \\ nil) do
    now = now || DateTime.utc_now() |> DateTime.truncate(:second)

    set_recipient_opened_at(recipient_id, now)

    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.clicked_at),
      select: struct(r, [:contact_id, :campaign_id])
    )
    |> Repo.update_all(set: [clicked_at: now])
    |> maybe_log_click_event()
  end

  defp set_recipient_opened_at(recipient_id, now \\ nil) do
    now = now || DateTime.utc_now() |> DateTime.truncate(:second)

    from(r in Recipient,
      where: r.id == ^recipient_id and is_nil(r.opened_at),
      select: struct(r, [:contact_id, :campaign_id])
    )
    |> Repo.update_all(set: [opened_at: now])
    |> maybe_log_open_event()
  end

  def maybe_log_click_event({1, [recipient]}) do
    Keila.Contacts.log_event(recipient.contact_id, :click, %{"campaign" => recipient.campaign_id})
  end

  def maybe_log_click_event(_), do: :ok

  def maybe_log_open_event({1, [recipient]}) do
    Keila.Contacts.log_event(recipient.contact_id, :open, %{"campaign" => recipient.campaign_id})
  end

  def maybe_log_open_event(_), do: :ok

  @doc """
  Retrieves statistics about links for a `Campaign` specified by `campaign_id`.
  """
  def get_link_stats(campaign_id) do
    from(l in Link, where: l.campaign_id == ^campaign_id)
    |> join(:left, [l], assoc(l, :clicks))
    |> group_by([l, c], l.url)
    |> order_by([l, c], desc: count(c.id), asc: l.url)
    |> select([l, c], [l.url, count(c.id)])
    |> Repo.all()
    |> Enum.map(&List.to_tuple/1)
  end

  defp create_hmac(encoded_url, recipient_id, link_id \\ nil) do
    :crypto.mac(:hmac, :sha256, hmac_key(), hmac_message(encoded_url, recipient_id, link_id))
    |> Base.url_encode64(padding: false)
  end

  defp verify_hmac(hmac, encoded_url, recipient_id, link_id \\ nil) do
    case create_hmac(encoded_url, recipient_id, link_id) do
      ^hmac -> :ok
      _other -> :error
    end
  end

  defp hmac_message(encoded_url, recipient_id, link_id) do
    :erlang.term_to_binary({encoded_url, recipient_id, link_id})
  end

  defp hmac_key,
    do: Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.get(:secret_key_base)

  @bot_user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246 Mozilla/5.0"
  defp is_user_agent_bot(user_agent) do
    user_agent == @bot_user_agent
  end
end
