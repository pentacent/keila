defmodule KeilaWeb.SegmentView do
  use KeilaWeb, :view

  defp render_widget(index, field_form_data)

  defp render_widget(index, condition = %{"widget" => widget, "type" => "date"})
       when widget in ["eq", "lt", "lte", "gt", "gte"] do
    value = condition["value"]
    date = if is_map(value), do: value["date"]
    time = if is_map(value), do: value["time"]
    timezone = if is_map(value), do: value["timezone"], else: "Etc/UTC"

    # If date != time, they are no longer the original ISO strings that need to
    # be processed by with phx-hook
    date_value = if date != time, do: date
    time_value = if date != time, do: time

    assigns = %{}

    ~H"""
    <input
      id={"#{index}[value][date]"}
      class="text-black"
      name={"#{index}[value][date]"}
      type="date"
      value={date_value}
      data-value={date}
      phx-hook="SetLocalDateValue"
      phx-update="ignore"
    />
    <input
      id={"#{index}[value][time]"}
      class="text-black"
      name={"#{index}[value][time]"}
      type="time"
      value={time_value}
      data-value={time}
      phx-hook="SetLocalTimeValue"
      phx-update="ignore"
    />
    <input
      id={"#{index}[value][timezone]"}
      class="bg-transparent text-white"
      name={"#{index}[value][timezone]"}
      type="text"
      readonly
      value={timezone}
      x-data="{}"
      :value="Intl.DateTimeFormat().resolvedOptions().timeZone"
      phx-update="ignore"
    />
    """
  end

  defp render_widget(index, condition = %{"widget" => widget, "type" => "string"})
       when widget in [
              "eq",
              "starts_with",
              "ends_with",
              "includes",
              "not_starts_with",
              "not_ends_with",
              "not_includes"
            ] do
    value = condition["value"]
    assigns = %{}

    ~H(<input
  id={"#{index}[value]"}
  name={"#{index}[value]"}
  type="text"
  value={value}
  class="text-black"
/>)
  end

  defp render_widget(index, condition = %{"type" => "custom"}) do
    value = condition["value"] || %{}
    key = value["key"]
    match = value["match"]
    assigns = %{}

    ~H"""
    <label for={"#{index}[value][key]"} class="self-center text-right">
      <%= gettext("Field:") %>
    </label>
    <input
      id={"#{index}[value][key]"}
      name={"#{index}[value][key]"}
      type="text"
      value={key}
      class="text-black w-28"
    />
    <label for={"#{index}[value][match]"} class="self-center text-right">
      <%= gettext("Match:") %>
    </label>
    <input
      id={"#{index}[value][match]"}
      name={"#{index}[value][match]"}
      type="text"
      value={match}
      class="text-black"
    />
    """
  end

  defp render_widget(_widget, field_form_data) do
    assigns = %{condition: field_form_data}
    ~H{<p><%= inspect(@condition) %></p>}
  end
end
