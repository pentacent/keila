defmodule KeilaWeb.RemoteIpPlug do
  @moduledoc """
  Plug that normalizes `conn.remote_ip` and replaces it with the forwarded
  client IP address if Keila is running behind a reverse proxy.

  Normalizing converts IPv4-mapped IPv6 addresses (e.g. `::ffff:192.0.2.1`)
  to IPv4.

  Configured via the `TRUSTED_PROXIES` and `TRUSTED_PROXY_HEADER` environment
  variables. Forwarded client IP addresses are only used if trusted proxies
  are configured and the TCP peer is a trusted proxy.
  """

  @behaviour Plug

  @type proxy ::
          {first :: :inet.ip_address(), last :: :inet.ip_address(),
           prefix_length :: non_neg_integer()}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    config = Application.get_env(:keila, __MODULE__, [])
    proxies = Keyword.get(config, :proxies, [])
    header = Keyword.get(config, :header, "x-forwarded-for")
    peer = normalize_ip(conn.remote_ip)

    if trusted_proxy?(peer, proxies) do
      %{conn | remote_ip: forwarded_client_ip(conn, header, proxies) || peer}
    else
      %{conn | remote_ip: peer}
    end
  end

  # Returns the rightmost IP address that is not a trusted proxy
  defp forwarded_client_ip(conn, header, proxies) do
    conn
    |> Plug.Conn.get_req_header(header)
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&parse_ip/1)
    |> Enum.map(&normalize_ip/1)
    |> Enum.reverse()
    |> Enum.find(&(not trusted_proxy?(&1, proxies)))
  end

  defp parse_ip(entry) do
    entry = entry |> String.trim() |> :binary.bin_to_list()

    case :inet.parse_strict_address(entry) do
      {:ok, ip} -> ip
      {:error, _} -> nil
    end
  end

  # IPv4-mapped IPv6 address (::ffff:a.b.c.d)
  defp normalize_ip({0, 0, 0, 0, 0, 0xFFFF, _, _} = ip), do: :inet.ipv4_mapped_ipv6_address(ip)
  defp normalize_ip(ip), do: ip

  defp trusted_proxy?(ip, proxies) do
    Enum.any?(proxies, &InetCidr.contains?(&1, ip))
  end

  @doc """
  Parses an IP address or CIDR range as used in `TRUSTED_PROXIES`.

  ## Examples

      iex> KeilaWeb.RemoteIpPlug.parse_proxy("172.18.0.0/16")
      {:ok, {{172, 18, 0, 0}, {172, 18, 255, 255}, 16}}

      iex> KeilaWeb.RemoteIpPlug.parse_proxy("10.0.0.5")
      {:ok, {{10, 0, 0, 5}, {10, 0, 0, 5}, 32}}

      iex> KeilaWeb.RemoteIpPlug.parse_proxy("10.0.0.0/33")
      :error
  """
  @spec parse_proxy(String.t()) :: {:ok, proxy()} | :error
  def parse_proxy(entry) do
    with {:ok, ip} <- parse_proxy_address(entry),
         cidr = maybe_add_prefix_length(entry, ip),
         {:ok, proxy} <- InetCidr.parse_cidr(cidr) do
      {:ok, proxy}
    else
      _ -> :error
    end
  end

  defp parse_proxy_address(entry) do
    [address | _] = String.split(entry, "/", parts: 2)
    address |> String.to_charlist() |> :inet.parse_strict_address()
  end

  defp maybe_add_prefix_length(entry, ip) do
    if String.contains?(entry, "/"), do: entry, else: "#{entry}/#{InetCidr.bit_count(ip)}"
  end
end
