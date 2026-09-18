defmodule KeilaWeb.HtmlEscapeHelper do
  @moduledoc """
  This module provides `escape/1` as a convenience wrapper around `Plug.HTML.html_escape`.
  """

  @spec escape(String.t() | nil) :: String.t()
  def escape(string) when is_binary(string), do: Plug.HTML.html_escape(string)
  def escape(nil), do: ""
end
