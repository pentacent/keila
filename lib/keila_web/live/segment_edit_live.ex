defmodule KeilaWeb.SegmentEditLive do
  use KeilaWeb, :live_view
  alias Keila.Contacts
  alias Keila.Mailings

  defp fields do
    %{
      "inserted_at" => %{type: "date", label: gettext("Date added")},
      "email" => %{type: "string", label: gettext("Email")},
      "first_name" => %{type: "string", label: gettext("First name")},
      "last_name" => %{type: "string", label: gettext("Last name")},
      "double_opt_in_at" => %{type: "date", label: gettext("Double opt-in date")},
      "data" => %{type: "custom", label: gettext("Custom data")},
      "messages" => %{type: "messages", label: gettext("Messages")}
    }
  end

  defp widgets() do
    %{
      "email" => [
        %{name: "eq", label: gettext("is equal")},
        %{name: "starts_with", label: gettext("starts with")},
        %{name: "ends_with", label: gettext("ends with")},
        %{name: "includes", label: gettext("includes")}
      ],
      "inserted_at" => [
        %{name: "lt", label: gettext("is before")},
        %{name: "gt", label: gettext("is after")}
      ],
      "double_opt_in_at" => [
        %{name: "lt", label: gettext("is before")},
        %{name: "gt", label: gettext("is after")},
        %{name: "empty", label: gettext("is empty")},
        %{name: "not_empty", label: gettext("is not empty")}
      ],
      "first_name" => [
        %{name: "eq", label: gettext("is equal")},
        %{name: "starts_with", label: gettext("starts with")},
        %{name: "ends_with", label: gettext("ends with")},
        %{name: "includes", label: gettext("includes")},
        %{name: "empty", label: gettext("is empty")},
        %{name: "not_empty", label: gettext("is not empty")}
      ],
      "last_name" => [
        %{name: "eq", label: gettext("is equal")},
        %{name: "starts_with", label: gettext("starts with")},
        %{name: "ends_with", label: gettext("ends with")},
        %{name: "includes", label: gettext("includes")},
        %{name: "empty", label: gettext("is empty")},
        %{name: "not_empty", label: gettext("is not empty")}
      ],
      "data" => [
        %{name: "matches", label: gettext("matches")},
        %{name: "empty", label: gettext("is empty")},
        %{name: "not_empty", label: gettext("is not empty")}
      ],
      "messages" => [
        %{name: "received", label: gettext("received")},
        %{name: "not_received", label: gettext("not received")},
        %{name: "opened", label: gettext("opened")},
        %{name: "not_opened", label: gettext("not opened")},
        %{name: "clicked", label: gettext("clicked")},
        %{name: "not_clicked", label: gettext("not clicked")},
        %{name: "bounced", label: gettext("bounced")},
        %{name: "not_bounced", label: gettext("not bounced")},
        %{name: "complained", label: gettext("complaint received")},
        %{name: "not_complained", label: gettext("no complaint received")}
      ]
    }
  end

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

    campaigns = Mailings.get_project_campaigns(session["current_project"].id)

    socket =
      socket
      |> assign(:current_project, session["current_project"])
      |> assign(:segment, session["segment"])
      |> assign(:changeset, Ecto.Changeset.change(session["segment"]))
      |> assign(:fields, fields())
      |> assign(:widgets, widgets())
      |> assign(:campaigns, campaigns)
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

      {actual_field, actual_condition, type} =
        case {field, condition} do
          {"$not", %{"messages" => inner}} ->
            # $not wrapping messages - pass the whole $not structure
            {"messages", %{"$not" => %{"messages" => inner}}, "messages"}

          {"messages", _} ->
            {"messages", condition, "messages"}

          {"data." <> _, _} ->
            {field, condition, "custom"}

          {field, _} ->
            {field, condition, fields()[field][:type] || "string"}
        end

      form_data =
        filter_condition_to_form_data(type, actual_field, actual_condition)
        |> Map.put("type", type)
        |> Map.put("field", actual_field)

      {to_string(condition_index), form_data}
    end)
    |> Enum.into(%{})
  end

  defp filter_condition_to_form_data(type, field, condition)

  defp filter_condition_to_form_data("string", _field, %{"$like" => value}) do
    cond do
      String.starts_with?(value, "%") && String.ends_with?(value, "%") ->
        %{"value" => String.slice(value, 1..-2//-1), "widget" => "includes"}

      String.starts_with?(value, "%") ->
        %{"value" => String.slice(value, 1..-1//-1), "widget" => "ends_with"}

      String.ends_with?(value, "%") ->
        %{"value" => String.slice(value, 0..-2//-1), "widget" => "starts_with"}
    end
  end

  defp filter_condition_to_form_data("string", _field, condition) when is_binary(condition) do
    %{"value" => condition, "widget" => "eq"}
  end

  defp filter_condition_to_form_data("string", _field, %{"$empty" => true}) do
    %{"value" => nil, "widget" => "empty"}
  end

  defp filter_condition_to_form_data("string", _field, %{"$empty" => false}) do
    %{"value" => nil, "widget" => "not_empty"}
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

  defp filter_condition_to_form_data("date", _field, %{"$empty" => true}) do
    %{"value" => nil, "widget" => "empty"}
  end

  defp filter_condition_to_form_data("date", _field, %{"$empty" => false}) do
    %{"value" => nil, "widget" => "not_empty"}
  end

  defp filter_condition_to_form_data("custom", "data." <> field, condition)
       when is_binary(condition) do
    %{"value" => %{"key" => field, "match" => condition}}
  end

  defp filter_condition_to_form_data("custom", "data." <> field, %{"$empty" => true}) do
    %{"value" => %{"key" => field}, "widget" => "empty"}
  end

  defp filter_condition_to_form_data("custom", "data." <> field, %{"$empty" => false}) do
    %{"value" => %{"key" => field}, "widget" => "not_empty"}
  end

  defp filter_condition_to_form_data("messages", _field, messages_condition) do
    # Handle message filters - check if entire messages condition is wrapped in $not
    {is_negated, inner_condition} =
      case messages_condition do
        %{"$not" => %{"messages" => inner}} -> {true, inner}
        %{"messages" => inner} -> {false, inner}
        _ -> {false, messages_condition}
      end

    # Extract campaign_id and field check
    {campaign_id, field_condition} =
      case inner_condition do
        %{"campaign_id" => cid} ->
          {cid, Map.delete(inner_condition, "campaign_id")}

        _ ->
          {nil, inner_condition}
      end

    # Determine the widget based on field check and negation
    widget =
      cond do
        Map.has_key?(field_condition, "sent_at") ->
          if is_negated, do: "not_received", else: "received"

        Map.has_key?(field_condition, "opened_at") ->
          if is_negated, do: "not_opened", else: "opened"

        Map.has_key?(field_condition, "clicked_at") ->
          if is_negated, do: "not_clicked", else: "clicked"

        Map.has_key?(field_condition, "bounced_at") ->
          if is_negated, do: "not_bounced", else: "bounced"

        Map.has_key?(field_condition, "complained_at") ->
          if is_negated, do: "not_complained", else: "complained"

        true ->
          # default
          "received"
      end

    %{"value" => %{"campaign_id" => campaign_id}, "widget" => widget}
  end

  # Transforms form_data to filter
  defp form_data_to_filter(form_data) do
    form_data
    |> Enum.sort_by(fn {group_index, _groups} -> group_index end)
    |> Enum.map(fn {_group_index, group} -> form_data_group_to_filter(group) end)
    |> Enum.reject(fn group -> group["$and"] == [] end)
    |> then(fn groups -> %{"$or" => groups} end)
  end

  defp form_data_group_to_filter(form_data_group) do
    form_data_group
    |> Enum.sort_by(fn {group_index, _form_data_conditions} -> group_index end)
    |> Enum.map(fn {_condition_index, form_data_condition} ->
      field = form_data_condition["field"]
      widget = form_data_condition["widget"]
      value = form_data_condition["value"]

      type =
        case field do
          "data." <> _ ->
            "custom"

          field ->
            case fields()[field] do
              %{type: t} -> t
              # Default to string type if field not found
              _ -> "string"
            end
        end

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

  defp form_data_condition_to_filter(field, "string", "empty", _value) do
    %{field => %{"$empty" => true}}
  end

  defp form_data_condition_to_filter(field, "string", "not_empty", _value) do
    %{field => %{"$empty" => false}}
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

  defp form_data_condition_to_filter(field, "date", "empty", _value) do
    %{field => %{"$empty" => true}}
  end

  defp form_data_condition_to_filter(field, "date", "not_empty", _value) do
    %{field => %{"$empty" => false}}
  end

  defp form_data_condition_to_filter(_field, "custom", widget, value)
       when widget in ["matches"] and is_map(value) do
    key = value["key"]
    match = value["match"]

    if key && match do
      %{("data." <> key) => match}
    end
  end

  defp form_data_condition_to_filter(_field, "custom", "empty", value) when is_map(value) do
    key = value["key"]

    if key do
      %{("data." <> key) => %{"$empty" => true}}
    end
  end

  defp form_data_condition_to_filter(_field, "custom", "not_empty", value) when is_map(value) do
    key = value["key"]

    if key do
      %{("data." <> key) => %{"$empty" => false}}
    end
  end

  defp form_data_condition_to_filter(_field, "messages", widget, value) when is_map(value) do
    campaign_id = value["campaign_id"]

    # Determine which field to check based on widget
    {field_name, is_negated} =
      case widget do
        "received" -> {"sent_at", false}
        "not_received" -> {"sent_at", true}
        "opened" -> {"opened_at", false}
        "not_opened" -> {"opened_at", true}
        "clicked" -> {"clicked_at", false}
        "not_clicked" -> {"clicked_at", true}
        "bounced" -> {"bounced_at", false}
        "not_bounced" -> {"bounced_at", true}
        "complained" -> {"complained_at", false}
        "not_complained" -> {"complained_at", true}
        _ -> {nil, false}
      end

    if field_name do
      base_filter = %{field_name => %{"$empty" => false}}

      # Add campaign_id if specified (not "any")
      filter_with_campaign =
        if campaign_id && campaign_id != "" && campaign_id != "any" do
          Map.put(base_filter, "campaign_id", campaign_id)
        else
          base_filter
        end

      # Wrap in "messages" key, then wrap entire thing in $not if negated
      if is_negated do
        %{"$not" => %{"messages" => filter_with_campaign}}
      else
        %{"messages" => filter_with_campaign}
      end
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
          field = condition["field"]

          type =
            case field do
              "messages" ->
                "messages"

              "data." <> _ ->
                "custom"

              field ->
                case fields()[field] do
                  %{type: t} -> t
                  # Default to string type if field not found
                  _ -> "string"
                end
            end

          allowed_widgets = Enum.map(widgets()[field], & &1.name)

          if condition["type"] != type || condition["widget"] not in allowed_widgets do
            default_value =
              case type do
                "messages" -> %{"campaign_id" => "any"}
                _ -> nil
              end

            condition =
              condition
              |> Map.put("type", type)
              |> Map.put("widget", allowed_widgets |> hd())
              |> Map.put("value", default_value)

            {condition_index, condition}
          else
            condition =
              if type == "messages" && (is_nil(condition["value"]) || condition["value"] == %{}) do
                Map.put(condition, "value", %{"campaign_id" => "any"})
              else
                condition
              end

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
