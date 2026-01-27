defmodule KeilaWeb.DateTimeHelpers do
  @moduledoc """
  Helper module for handling datetimes in views.
  """

  use PhoenixHTMLHelpers

  @doc """
  Render `span` tag with formatted UTC date.
  The date is automatically translated and localized client-side via hook.

  Optionally, the resolution can be set to `:minute` or `:second`.
  """
  @spec local_datetime_tag(DateTime.t(), :minute | :second) :: Phoenix.HTML.safe()
  def local_datetime_tag(datetime, resolution \\ :minute)

  def local_datetime_tag(datetime = %DateTime{}, resolution) do
    content_tag(
      :span,
      Calendar.strftime(datetime, "%a, %b %d %Y, %H:%M"),
      data_value: DateTime.to_iso8601(datetime),
      x_data: "{}",
      data_resolution: resolution,
      x_init: "Hooks.SetLocalDateTimeContent.mounted.call({el: $el})"
    )
  end

  def local_datetime_tag(_, _), do: []

  @doc """
  Render `span` tag with formatted local date.
  The date is automatically translated and localized client-side via hook.
  """
  @spec local_date_tag(Date.t()) :: Phoenix.HTML.safe()
  def local_date_tag(date = %Date{}) do
    content_tag(
      :span,
      Calendar.strftime(date, "%b %d, %Y"),
      data_value: Date.to_iso8601(date),
      x_data: "{}",
      x_init: "Hooks.SetLocalDateContent.mounted.call({el: $el})"
    )
  end

  def local_date_tag(_), do: []

  @doc """
  Returns a datetime in ISO 8601 format or an empty string if given `nil`.
  """
  @spec maybe_print_datetime(DateTime.t() | nil) :: String.t()
  def maybe_print_datetime(datetime = %DateTime{}), do: DateTime.to_iso8601(datetime)
  def maybe_print_datetime(_), do: ""
end
