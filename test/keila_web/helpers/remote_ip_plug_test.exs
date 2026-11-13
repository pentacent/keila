defmodule KeilaWeb.RemoteIpPlugTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias KeilaWeb.RemoteIpPlug

  doctest KeilaWeb.RemoteIpPlug

  setup do
    config_before = Application.get_env(:keila, RemoteIpPlug)

    on_exit(fn ->
      if config_before do
        Application.put_env(:keila, RemoteIpPlug, config_before)
      else
        Application.delete_env(:keila, RemoteIpPlug)
      end
    end)
  end

  defp put_trusted_proxies(entries, header \\ "x-forwarded-for") do
    proxies =
      Enum.map(entries, fn entry ->
        {:ok, proxy} = RemoteIpPlug.parse_proxy(entry)
        proxy
      end)

    Application.put_env(:keila, RemoteIpPlug, proxies: proxies, header: header)
  end

  defp request(peer, headers \\ []) do
    conn(:get, "/")
    |> Map.put(:remote_ip, peer)
    |> then(fn conn ->
      Enum.reduce(headers, conn, fn {name, value}, conn -> put_req_header(conn, name, value) end)
    end)
    |> RemoteIpPlug.call([])
  end

  @tag :remote_ip_plug
  test "ignores forwarding headers if no trusted proxies are configured" do
    Application.delete_env(:keila, RemoteIpPlug)

    conn = request({172, 18, 0, 2}, [{"x-forwarded-for", "203.0.113.7"}])
    assert conn.remote_ip == {172, 18, 0, 2}
  end

  @tag :remote_ip_plug
  test "uses the forwarding header if the peer is a trusted proxy" do
    put_trusted_proxies(["172.18.0.0/16"])

    conn = request({172, 18, 0, 2}, [{"x-forwarded-for", "203.0.113.7"}])
    assert conn.remote_ip == {203, 0, 113, 7}
  end

  @tag :remote_ip_plug
  test "ignores forwarding headers if the peer is not a trusted proxy" do
    put_trusted_proxies(["172.18.0.0/16"])

    conn = request({198, 51, 100, 9}, [{"x-forwarded-for", "203.0.113.7"}])
    assert conn.remote_ip == {198, 51, 100, 9}
  end

  @tag :remote_ip_plug
  test "ignores addresses spoofed by the client left of the address added by the proxy" do
    put_trusted_proxies(["172.18.0.0/16"])

    conn = request({172, 18, 0, 2}, [{"x-forwarded-for", "1.2.3.4, 203.0.113.7"}])
    assert conn.remote_ip == {203, 0, 113, 7}
  end

  @tag :remote_ip_plug
  test "does not skip invalid addresses added by the proxy" do
    put_trusted_proxies(["172.18.0.0/16"])

    conn = request({172, 18, 0, 2}, [{"x-forwarded-for", "1.2.3.4, unknown"}])
    assert conn.remote_ip == {172, 18, 0, 2}
  end

  @tag :remote_ip_plug
  test "skips all trusted proxies in a chain of proxies" do
    put_trusted_proxies(["172.18.0.0/16", "198.51.100.0/24"])

    conn =
      request({172, 18, 0, 2}, [{"x-forwarded-for", "1.2.3.4, 203.0.113.7, 198.51.100.9"}])

    assert conn.remote_ip == {203, 0, 113, 7}
  end

  @tag :remote_ip_plug
  test "reads multiple header lines in order" do
    put_trusted_proxies(["172.18.0.0/16"])

    conn =
      conn(:get, "/")
      |> Map.put(:remote_ip, {172, 18, 0, 2})
      |> Map.update!(:req_headers, fn headers ->
        headers ++ [{"x-forwarded-for", "1.2.3.4"}, {"x-forwarded-for", "203.0.113.7"}]
      end)
      |> RemoteIpPlug.call([])

    assert conn.remote_ip == {203, 0, 113, 7}
  end

  @tag :remote_ip_plug
  test "only reads the configured header" do
    put_trusted_proxies(["172.18.0.0/16"], "cf-connecting-ip")

    conn =
      request({172, 18, 0, 2}, [
        {"x-forwarded-for", "1.2.3.4"},
        {"cf-connecting-ip", "203.0.113.7"}
      ])

    assert conn.remote_ip == {203, 0, 113, 7}
  end

  @tag :remote_ip_plug
  test "keeps the peer address if the header is missing or invalid" do
    put_trusted_proxies(["172.18.0.0/16"])

    assert request({172, 18, 0, 2}).remote_ip == {172, 18, 0, 2}

    assert request({172, 18, 0, 2}, [{"x-forwarded-for", "203.0.113.7\xFF"}]).remote_ip ==
             {172, 18, 0, 2}
  end

  @tag :remote_ip_plug
  test "converts IPv4-mapped IPv6 addresses to IPv4" do
    put_trusted_proxies(["172.18.0.0/16"])

    # ::ffff:172.18.0.2
    peer = {0, 0, 0, 0, 0, 0xFFFF, 0xAC12, 0x0002}

    conn = request(peer, [{"x-forwarded-for", "::ffff:203.0.113.7"}])
    assert conn.remote_ip == {203, 0, 113, 7}

    Application.delete_env(:keila, RemoteIpPlug)
    assert request(peer).remote_ip == {172, 18, 0, 2}
  end

  @tag :remote_ip_plug
  test "supports IPv6 proxies" do
    put_trusted_proxies(["fd00::1"])

    conn = request({0xFD00, 0, 0, 0, 0, 0, 0, 1}, [{"x-forwarded-for", "2001:db8::1"}])
    assert conn.remote_ip == {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1}
  end

  @tag :remote_ip_plug
  test "parse_proxy/1 rejects invalid entries" do
    for entry <- ["1.2.3", "example.com"] do
      assert :error == RemoteIpPlug.parse_proxy(entry)
    end
  end
end
