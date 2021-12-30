defmodule KeilaWeb.ApiSegmentView do
  use KeilaWeb, :view
  alias Keila.Pagination

  def render("segments.json", %{segments: segments = %Pagination{}}) do
    %{
      "meta" => %{
        "page" => segments.page,
        "page_count" => segments.page_count,
        "count" => segments.count
      },
      "data" => Enum.map(segments.data, &segment_data/1)
    }
  end

  def render("segment.json", %{segment: segment}) do
    %{
      "data" => segment_data(segment)
    }
  end

  @properties [:id, :name, :filter]
  defp segment_data(segment) do
    segment
    |> Map.take(@properties)
  end
end
