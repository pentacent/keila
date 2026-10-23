defmodule KeilaWeb.Api.ContactSortValidator do
  @moduledoc """
  OpenApiSpex cast module for casting the `sort` query parameter from a JSON
  string to an ordered list of `{field, direction}` tuples.

  Accepts either a JSON object (`{"email": 1, "inserted_at": -1}`) or a JSON
  array of pairs (`[["email", 1], ["inserted_at", -1]]`). The array form
  preserves key order, which Elixir maps do not guarantee.
  """

  def cast(ctx = %{value: value}) do
    with {:ok, json} <- Jason.decode(value) do
      {:ok, normalize(json)}
    else
      _ -> OpenApiSpex.Cast.error(ctx, {:invalid_type, :object})
    end
  end

  defp normalize(map) when is_map(map) do
    Enum.to_list(map)
  end

  defp normalize(list) when is_list(list) do
    Enum.map(list, fn
      [field, direction] -> {field, direction}
      {field, direction} -> {field, direction}
    end)
  end
end
