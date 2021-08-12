defmodule KeilaWeb.PlainTextJSONParser do
  @moduledoc """
  This Parser plug is used to requests with content-type `text/plain` as JSON.

  It’s necessary to use this plug when external applications (e.g. webhooks)
  use `text/plain` instead of `application/json`.
  """

  @behaviour Plug.Parsers

  @impl true
  def init(opts) do
    Plug.Parsers.JSON.init(opts)
  end

  @impl true
  def parse(conn, "text", "plain", params, opts) do
    Plug.Parsers.JSON.parse(conn, "application", "json", params, opts)
  end

  def parse(conn, _type, _subtype, _params, _opts) do
    {:next, conn}
  end
end
