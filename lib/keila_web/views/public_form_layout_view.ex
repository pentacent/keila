defmodule KeilaWeb.PublicFormLayoutView do
  use KeilaWeb, :view
  use PhoenixHTMLHelpers

  def build_styles(styles) do
    styles
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
    |> Enum.map(fn {key, value} -> ~s{#{key}:#{value}!important} end)
    |> Enum.join(";")
  end
end
