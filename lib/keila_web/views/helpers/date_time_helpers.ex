defmodule KeilaWeb.DateTimeHelpers do
  @moduledoc """
  Helper module for printing span tags with date time content.
  Content is automatically translated and localized client-side via hook.
  """

  use Phoenix.HTML

  @spec local_date_time_tag(DateTime.t()) :: Phoenix.HTML.safe()
  def local_date_time_tag(datetime = %DateTime{}) do
    content_tag(
        :span,
        Calendar.strftime(datetime, "%a, %b %d %Y, %H:%M"),
        data_value: DateTime.to_iso8601(datetime),
        x_data: "{}",
        x_init: "Hooks.SetLocalDateTimeContent.mounted.call({el: $el})"
    )
  end

  def local_date_time_tag(_), do: []
end
