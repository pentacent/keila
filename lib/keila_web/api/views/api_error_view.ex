defmodule KeilaWeb.ApiErrorView do
  def render("error.json", %{error: error}) do
    render("errors.json", %{errors: [error]})
  end

  def render("errors.json", %{errors: errors}) do
    %{
      "errors" => Enum.map(errors, &error_object/1)
    }
  end

  defp error_object(error) do
    error_object(error[:title], error[:detail])
    |> Map.put_new_lazy("status", fn -> error |> Keyword.fetch!(:status) |> to_string() end)
  end

  defp error_object(title, detail = %Jason.DecodeError{}) do
    title = title || "Invalid JSON"
    detail = Jason.DecodeError.message(detail)
    %{"title" => title, "detail" => detail}
  end

  defp error_object(title, changeset = %Ecto.Changeset{}) do
    {field, {message, _}} = changeset.errors |> List.first()

    %{
      "title" => title || "Validation failed",
      "detail" => message,
      "pointer" => "/data/attributes/#{field}"
    }
  end

  defp error_object(title, error = %OpenApiSpex.Cast.Error{reason: :unexpected_field}) do
    %{
      "title" => title || "Unexpected field"
    }
    |> put_open_api_spex_pointer(error)
  end

  defp error_object(title, error = %OpenApiSpex.Cast.Error{reason: :missing_field}) do
    %{
      "title" => title || "Missing field"
    }
    |> put_open_api_spex_pointer(error)
  end

  defp error_object(title, error = %OpenApiSpex.Cast.Error{}) do
    %{
      "title" => title || "Request error: #{error.reason}"
    }
    |> put_open_api_spex_pointer(error)
  end

  defp error_object(title, detail) when is_binary(title) and is_binary(detail),
    do: %{"title" => title, "detail" => detail}

  defp error_object(title, nil) when is_binary(title), do: %{"title" => title}
  defp error_object(nil, detail) when is_binary(detail), do: %{"detail" => detail}

  # Since the OpenApiSpex error struct doesn’t provide information on whether
  # the error originated from a query parameter or from the request body,
  # the assumption is that any path starting with data will be from the request
  # body and all other paths will be from query parameters.
  defp put_open_api_spex_pointer(error_object, error = %{path: [:data | _]}) do
    Map.put(error_object, "pointer", "/" <> Enum.join(error.path, "/"))
  end

  defp put_open_api_spex_pointer(error_object, %{path: [parameter]})
       when is_atom(parameter) do
    Map.put(error_object, "parameter", parameter)
  end

  defp put_open_api_spex_pointer(error_object, _error) do
    error_object
  end
end
