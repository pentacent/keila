defmodule KeilaWeb.SegmentEditLive do
  use KeilaWeb, :live_view
  alias Keila.Contacts

  @fields %{
    "inserted_at" => %{type: "date", label: gettext("Date added")},
    "email" => %{type: "string", label: gettext("Email")},
    "first_name" => %{type: "string", label: gettext("First name")},
    "last_name" => %{type: "string", label: gettext("Last name")},
    "double_opt_in_at" => %{type: "date", label: gettext("Double opt-in date")},
    "data" => %{type: "custom", label: gettext("Custom data")}
  }

  @widgets %{
    "date" => [
      %{name: "lt", label: gettext("is before")},
      %{name: "gt", label: gettext("is after")}
    ],
    "string" => [
      %{name: "eq", label: gettext("is equal")},
      %{name: "starts_with", label: gettext("starts with")},
      %{name: "ends_with", label: gettext("ends with")},
      %{name: "includes", label: gettext("includes")}
    ],
    "custom" => [
      %{name: "matches", label: gettext("matches")}
    ]
  }

  @empty_state %{"0" => %{}}
  @default_field %{
    "field" => "inserted_at",
    "type" => "date",
    "widget" => "lt",
    "value" => nil
  }

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])

    socket =
      socket
      |> assign(:current_project, session["current_project"])
      |> assign(:segment, session["segment"])
      |> assign(:changeset, Ecto.Changeset.change(session["segment"]))
      |> assign(:fields, @fields)
      |> assign(:widgets, @widgets)
      |> assign(:page, 0)
      |> put_filter(session["segment"].filter || %{})
      |> update_assigns()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.SegmentView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("save", params, socket) do
    socket =
      socket
      |> put_form_data(params["filter"])
      |> save(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change", %{"filter" => form_data}, socket) do
    socket =
      socket
      |> put_form_data(form_data)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add-group", _params, socket) do
    form_data = socket.assigns.form_data
    group_index = Enum.count(form_data)
    updated_form_data = Map.put(form_data, to_string(group_index), %{})

    socket =
      assign(socket, :form_data, updated_form_data)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("add-field", %{"group" => group}, socket) do
    updated_form_data =
      Map.update!(socket.assigns.form_data, group, fn form_data_group ->
        field_index = Enum.count(form_data_group)

        Map.put(form_data_group, to_string(field_index), @default_field)
      end)

    socket =
      socket
      |> put_form_data(updated_form_data)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-field", %{"group" => group, "field" => field}, socket) do
    updated_form_data =
      Map.update!(socket.assigns.form_data, group, fn form_data_group ->
        form_data_group
        |> Map.delete(field)
        |> Enum.with_index()
        |> Enum.map(fn {{_, value}, index} -> {to_string(index), value} end)
        |> Enum.into(%{})
      end)

    socket =
      socket
      |> put_form_data(updated_form_data)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-editor", _params, socket) do
    use_editor? = !socket.assigns.use_editor

    socket =
      socket
      |> assign(:use_editor, use_editor?)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change-page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> put_contacts()

    {:noreply, socket}
  end

  defp update_assigns(socket) do
    socket
    |> put_contacts()
    |> ensure_valid_pagination()
  end

  defp put_contacts(socket) do
    query_opts = [
      filter: socket.assigns.filter,
      paginate: [page: socket.assigns.page, page_size: 10]
    ]

    contacts = Contacts.get_project_contacts(socket.assigns.current_project.id, query_opts)

    socket
    |> assign(:contacts, contacts)
  end

  defp ensure_valid_pagination(socket) do
    page = socket.assigns.page

    if page > 0 && page > socket.assigns.contacts.page_count do
      socket
      |> assign(:page, 0)
      |> put_contacts()
    else
      socket
    end
  end

  defp put_filter(socket, filter) do
    use_editor? = if socket.assigns[:use_editor] == nil, do: true, else: socket.assigns.use_editor

    case filter_to_form_data(filter) do
      {:ok, form_data} ->
        socket
        |> assign(:use_editor, use_editor?)
        |> assign(:can_use_editor, true)
        |> assign(:form_data, form_data)
        |> assign(:filter, filter)
        |> assign(:filter_json, Jason.encode!(filter))
        |> assign(:valid_filter, true)

      :error ->
        socket
        |> assign(:use_editor, false)
        |> assign(:can_use_editor, false)
        |> assign(:form_data, %{})
        |> assign(:filter, filter)
        |> assign(:filter_json, Jason.encode!(filter))
        |> assign(:valid_filter, true)
    end
  end

  defp put_form_data(socket, empty) when empty in [nil, ""] do
    socket
    |> assign(:form_data, @empty_state)
  end

  defp put_form_data(socket = %{assigns: %{use_editor: true}}, form_data) do
    form_data = form_data |> sanitize_form_data()
    filter = form_data_to_filter(form_data)

    socket
    |> assign(:form_data, form_data)
    |> assign(:filter, filter)
    |> assign(:filter_json, Jason.encode!(filter))
    |> assign(:valid_filter, true)
  end

  defp put_form_data(socket = %{assigns: %{use_editor: false}}, form_data) do
    filter_json = form_data

    with {:ok, filter} <- Jason.decode(filter_json),
         true <- Contacts.Query.valid_opts?(filter: filter) do
      socket
      |> assign(:filter, filter)
      |> assign(:filter_json, filter_json)
      |> assign(:can_use_editor, match?({:ok, _}, filter_to_form_data(filter)))
      |> assign(:valid_filter, true)
    else
      _ -> socket |> assign(:valid_filter, false)
    end
  end

  defp filter_to_form_data(filter) do
    try do
      form_data = filter_to_form_data!(filter)
      {:ok, form_data}
    rescue
      _e ->
        :error
    end
  end

  # Transforms filter to form data
  # Raises FunctionClauseError if filter can't be represented with form data
  defp filter_to_form_data!(filter) when is_nil(filter) or filter == %{} do
    @empty_state
  end

  defp filter_to_form_data!(filter) do
    Map.get(filter, "$or")
    |> Enum.with_index()
    |> Enum.map(fn {filter_group, group_index} ->
      {to_string(group_index), filter_group_to_form_data(filter_group)}
    end)
    |> Enum.into(%{})
  end

  defp filter_group_to_form_data(%{"$and" => conditions}) do
    conditions
    |> Enum.with_index()
    |> Enum.map(fn {condition, condition_index} ->
      {field, condition} = Enum.at(condition, 0)

      type =
        case field do
          "data." <> _ -> "custom"
          field -> @fields[field].type
        end

      form_data =
        filter_condition_to_form_data(type, field, condition)
        |> Map.put("type", type)
        |> Map.put("field", field)

      {to_string(condition_index), form_data}
    end)
    |> Enum.into(%{})
  end

  defp filter_condition_to_form_data(type, field, condition)

  defp filter_condition_to_form_data("string", _field, %{"$like" => value}) do
    cond do
      String.starts_with?(value, "%") && String.ends_with?(value, "%") ->
        %{"value" => String.slice(value, 1..-2), "widget" => "includes"}

      String.starts_with?(value, "%") ->
        %{"value" => String.slice(value, 1..-1), "widget" => "starts_with"}

      String.ends_with?(value, "%") ->
        %{"value" => String.slice(value, 0..-2), "widget" => "ends_with"}
    end
  end

  defp filter_condition_to_form_data("string", _field, condition) when is_binary(condition) do
    %{"value" => condition, "widget" => "eq"}
  end

  defp filter_condition_to_form_data("date", _field, condition) when is_map(condition) do
    {widget, datetime_string} =
      case condition do
        %{"$lt" => datetime} -> {"lt", datetime}
        %{"$gt" => datetime} -> {"gt", datetime}
      end

    {:ok, datetime, _} = DateTime.from_iso8601(datetime_string)

    value = %{
      "date" => DateTime.to_iso8601(datetime),
      "time" => DateTime.to_iso8601(datetime),
      "timezone" => "Etc/UTC"
    }

    %{"value" => value, "widget" => widget}
  end

  defp filter_condition_to_form_data("custom", "data." <> field, condition)
       when is_binary(condition) do
    %{"value" => %{"key" => field, "match" => condition}}
  end

  # Transforms form_data to filter
  defp form_data_to_filter(form_data) do
    form_data
    |> Enum.sort_by(fn {group_index, _groups} -> group_index end)
    |> Enum.map(fn {_group_index, group} -> form_data_group_to_filter(group) end)
    |> then(fn groups -> %{"$or" => groups} end)
  end

  defp form_data_group_to_filter(form_data_group) do
    form_data_group
    |> Enum.sort_by(fn {group_index, _form_data_conditions} -> group_index end)
    |> Enum.map(fn {_condition_index, form_data_condition} ->
      field = form_data_condition["field"]
      widget = form_data_condition["widget"]
      value = form_data_condition["value"]
      type = @fields[field].type
      form_data_condition_to_filter(field, type, widget, value)
    end)
    |> Enum.filter(& &1)
    |> then(fn conditions -> %{"$and" => conditions} end)
  end

  defp form_data_condition_to_filter(field, type, widget, value)

  defp form_data_condition_to_filter(field, "string", "eq", value) when is_binary(value) do
    %{field => value}
  end

  defp form_data_condition_to_filter(field, "string", "includes", value) when is_binary(value) do
    %{field => %{"$like" => "%" <> value <> "%"}}
  end

  defp form_data_condition_to_filter(field, "string", "starts_with", value)
       when is_binary(value) do
    %{field => %{"$like" => value <> "%"}}
  end

  defp form_data_condition_to_filter(field, "string", "ends_with", value) when is_binary(value) do
    %{field => %{"$like" => "%" <> value}}
  end

  defp form_data_condition_to_filter(field, "date", widget, value)
       when widget in ["lt", "lte", "gt", "gte"] and is_map(value) do
    with {:ok, date} <- Date.from_iso8601(value["date"]),
         {:ok, time} <- Time.from_iso8601(value["time"] <> ":00"),
         {:ok, datetime} <- DateTime.new(date, time, value["timezone"]),
         {:ok, utc_datetime} <- DateTime.shift_zone(datetime, "Etc/UTC") do
      %{field => %{("$" <> widget) => utc_datetime}}
    else
      _ -> nil
    end
  end

  defp form_data_condition_to_filter(_field, "custom", widget, value)
       when widget in ["matches"] and is_map(value) do
    key = value["key"]
    match = value["match"]

    if key && match do
      %{("data." <> key) => match}
    end
  end

  defp form_data_condition_to_filter(_, _, _, _) do
    nil
  end

  # Ensures correct types and widgets for all conditions
  defp sanitize_form_data(form_data) when is_map(form_data) do
    form_data
    |> Enum.map(fn {group_index, form_data_conditions} ->
      form_data_conditions =
        form_data_conditions
        |> Enum.map(fn {condition_index, condition} ->
          type = @fields[condition["field"]].type
          allowed_widgets = Enum.map(@widgets[type], & &1.name)

          if condition["type"] != type || condition["widget"] not in allowed_widgets do
            condition =
              condition
              |> Map.put("type", type)
              |> Map.put("widget", allowed_widgets |> hd())
              |> Map.put("value", nil)

            {condition_index, condition}
          else
            {condition_index, condition}
          end
        end)
        |> Enum.into(%{})

      {group_index, form_data_conditions}
    end)
    |> Enum.into(%{})
  end

  defp save(socket, params) do
    name = get_in(params, ["segment", "name"])
    filter = socket.assigns.filter
    params = %{"name" => name, "filter" => filter}

    case Contacts.update_segment(socket.assigns.segment.id, params) do
      {:ok, _} ->
        redirect(socket,
          to: Routes.segment_path(KeilaWeb.Endpoint, :index, socket.assigns.current_project.id)
        )

      {:error, changeset} ->
        assign(socket, :changeset, changeset)
    end
  end
end
