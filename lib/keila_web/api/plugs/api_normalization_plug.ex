defmodule KeilaWeb.Api.Plugs.Normalization do
  @moduledoc """
  Plug for normalizing API requests using their OpenApiSpex schemas.
  """

  @behaviour Plug
  import Plug.Conn
  alias KeilaWeb.Api.Errors

  def init(_opts) do
    nil
  end

  def call(conn, _) do
    spec = KeilaWeb.ApiSpec.spec()

    operation = get_operation(conn, spec)

    with {:ok, conn} <- OpenApiSpex.cast_and_validate(spec, operation, conn) do
      conn
    else
      {:error, errors} ->
        conn
        |> Errors.send_open_api_spex_errors(errors)
        |> halt()
    end
  end

  def get_operation(conn, spec) do
    operations =
      spec
      |> Map.get(:paths)
      |> Stream.flat_map(fn {_name, item} -> Map.values(item) end)
      |> Stream.filter(fn x -> match?(%OpenApiSpex.Operation{}, x) end)
      |> Stream.map(fn operation -> {operation.operationId, operation} end)
      |> Enum.into(%{})

    "Elixir." <> operation_id =
      "#{Phoenix.Controller.controller_module(conn)}.#{Phoenix.Controller.action_name(conn)}"

    operations[operation_id]
  end
end
