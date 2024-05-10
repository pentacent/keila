defmodule Keila.Tracking do
  @moduledoc """
  Module for handling and tracking events.
  """

  use Keila.Repo
  alias __MODULE__.{Link, Click, Event}
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
  Tracks the click on a registered link and returns the decoded URL.
  """
  @spec track_click_and_get_link(String.t(), Recipient.id(), Link.id(), String.t(), Keyword.t()) ::
          {:ok, url :: String.t()} | :error
  def track_click_and_get_link(encoded_url, recipient_id, link_id, hmac, opts \\ []) do
    if valid_hmac?(hmac, encoded_url, recipient_id, link_id) do
      unless is_bot?(opts[:user_agent]) do
        Click.changeset(%{recipient_id: recipient_id, link_id: link_id})
        |> Repo.insert!()

        Keila.Mailings.handle_recipient_click(recipient_id)
      end

      {:ok, URI.decode_www_form(encoded_url)}
    else
      :error
    end
  end

  @doc """
  Tracks a campaign open event and returns the decoded URL.
  """
  @spec track_open_and_get_link(String.t(), Recipient.id(), String.t(), Keyword.t()) ::
          {:ok, url :: String.t()} | :error
  def track_open_and_get_link(encoded_url, recipient_id, hmac, opts \\ []) do
    if valid_hmac?(hmac, encoded_url, recipient_id) do
      unless is_bot?(opts[:user_agent]) do
        Keila.Mailings.handle_recipient_open(recipient_id)
      end

      {:ok, URI.decode_www_form(encoded_url)}
    else
      :error
    end
  end

  defp valid_hmac?(hmac, encoded_url, recipient_id, link_id \\ nil) do
    case create_hmac(encoded_url, recipient_id, link_id) do
      ^hmac -> true
      _other -> false
    end
  end

  @spec log_event(type :: String.t() | atom(), Contact.id(), Recipient.id() | nil, map()) ::
          {:ok, Event.t()}
  def log_event(type, contact_id, recipient_id \\ nil, data) do
    %{type: type, contact_id: contact_id, recipient_id: recipient_id, data: data}
    |> Event.changeset()
    |> Repo.insert()
  end

  @doc """
  Returns list of all Events for given `contact_id`.
  Events are sorted from latest to oldest.
  """
  @spec get_contact_events(Contact.id()) :: [Event.t()]
  def get_contact_events(contact_id) do
    from(e in Event,
      where: e.contact_id == ^contact_id,
      order_by: [desc: e.inserted_at],
      preload: [recipient: :campaign]
    )
    |> Repo.all()
  end

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
    key = Application.get_env(:keila, KeilaWeb.Endpoint) |> Keyword.fetch!(:secret_key_base)
    message = :erlang.term_to_binary({encoded_url, recipient_id, link_id})

    :crypto.mac(:hmac, :sha256, key, message)
    |> Base.url_encode64(padding: false)
  end

  @bot_user_agents [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246 Mozilla/5.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"
  ]
  defp is_bot?(user_agent) do
    user_agent in @bot_user_agents
  end
end
