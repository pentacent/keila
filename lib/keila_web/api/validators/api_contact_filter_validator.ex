defmodule KeilaWeb.Api.ContactFilterValidator do
  @moduledoc """
  OpenApiSpex cast module for casting JSON string to Map.
  """

  def cast(ctx = %{value: value}) do
    with {:ok, json} <- Jason.decode(value) do
      {:ok, json}
    else
      _ -> OpenApiSpex.Cast.error(ctx, {:invalid_type, :object})
    end
  end
end
