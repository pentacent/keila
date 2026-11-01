defmodule KeilaWeb.NotFoundError do
  @moduledoc """
  This exception can be raised from a controller to respond with the 404 page
  from `KeilaWeb.ErrorView`.
  """
  defexception message: "Not Found", plug_status: 404
end
