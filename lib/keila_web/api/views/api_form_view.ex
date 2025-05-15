defmodule KeilaWeb.ApiFormView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("forms.json", %{forms: forms = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => forms.page,
        "page_count" => forms.page_count,
        "count" => forms.count
      },
      "data" => Enum.map(forms.data, &form_data/1)
    }
  end

  def render("form.json", %{form: form}) do
    %{
      "data" => form_data(form)
    }
  end

  def render("double_opt_in_required.json", _) do
    %{
      "data" => %{
        "double_opt_in_required" => true
      }
    }
  end

  @properties [:id, :name, :settings, :field_settings, :sender_id, :template_id]

  defp form_data(form) do
    form
    |> Map.take(@properties)
    |> Map.update!(:settings, &settings_data/1)
    |> Map.update!(:field_settings, &field_settings_data/1)
    |> then(fn form_data ->
      field_settings = form_data.field_settings

      form_data
      |> Map.delete(:field_settings)
      |> Map.put(:fields, field_settings)
    end)
  end

  defp settings_data(nil), do: %{}
  defp settings_data(settings), do: settings |> Map.from_struct() |> Map.drop([:id])

  defp field_settings_data(nil), do: %{}

  defp field_settings_data(field_settings) do
    field_settings
    |> Enum.map(fn field_settings ->
      field_settings
      |> Map.from_struct()
      |> Map.drop([:id])
      |> Map.update!(:allowed_values, fn
        nil ->
          nil

        allowed_values ->
          Enum.map(allowed_values, fn allowed_value ->
            Map.take(allowed_value, [:label, :value])
          end)
      end)
      |> then(fn
        field = %{field: :data} -> field
        field -> Map.drop(field, [:type, :key])
      end)
    end)
  end
end
