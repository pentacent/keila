defmodule KeilaWeb.SegmentEditLiveTest do
  use KeilaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Keila.Contacts

  @endpoint KeilaWeb.Endpoint

  setup %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    %{conn: conn, project: project}
  end

  defp edit_live(conn, project, filter) do
    segment = insert!(:contacts_segment, project_id: project.id, filter: filter)
    {:ok, view, html} = live(conn, Routes.segment_path(conn, :edit, project.id, segment.id))
    {view, html}
  end

  # Wraps a single custom-data condition in the group/condition form structure.
  defp custom_form_data(widget, value) do
    %{
      "0" => %{
        "0" => %{
          "field" => "data",
          "type" => "custom",
          "widget" => widget,
          "value" => value
        }
      }
    }
  end

  defp wrap(condition), do: %{"$or" => [%{"$and" => [condition]}]}

  # Runs form data through the editor and returns the persisted filter. Saving
  # reads the actual filter map back from the database, avoiding any HTML
  # entity-encoding in the query textarea.
  defp compiled_filter(conn, project, form_data) do
    segment = insert!(:contacts_segment, project_id: project.id, filter: %{})

    {:ok, view, _html} =
      live(conn, Routes.segment_path(conn, :edit, project.id, segment.id))

    render_hook(view, "save", %{"segment" => %{"name" => "Test"}, "filter" => form_data})
    Contacts.get_segment(segment.id).filter
  end

  defp selected_widget(html) do
    {:ok, doc} = Floki.parse_document(html)

    doc
    |> Floki.find("select[name$='[widget]'] option[selected]")
    |> Floki.attribute("value")
  end

  defp input_value(html, suffix) do
    {:ok, doc} = Floki.parse_document(html)

    doc
    |> Floki.find("input[name$='#{suffix}']")
    |> Floki.attribute("value")
  end

  describe "custom data operators — form to filter" do
    test "starts_with / ends_with / includes compile to $like patterns", %{
      conn: conn,
      project: project
    } do
      assert compiled_filter(conn, project, custom_form_data("starts_with", %{"key" => "city", "match" => "Ber"})) ==
               wrap(%{"data.city" => %{"$like" => "Ber%"}})

      assert compiled_filter(conn, project, custom_form_data("ends_with", %{"key" => "city", "match" => "lin"})) ==
               wrap(%{"data.city" => %{"$like" => "%lin"}})

      assert compiled_filter(conn, project, custom_form_data("includes", %{"key" => "city", "match" => "erl"})) ==
               wrap(%{"data.city" => %{"$like" => "%erl%"}})
    end

    test "greater/smaller than compile to numeric $gt/$lt (not strings)", %{
      conn: conn,
      project: project
    } do
      # The value must be a JSON number, otherwise JSONB comparison is wrong.
      assert compiled_filter(conn, project, custom_form_data("gt", %{"key" => "age", "match" => "40"})) ==
               wrap(%{"data.age" => %{"$gt" => 40}})

      assert compiled_filter(conn, project, custom_form_data("lt", %{"key" => "score", "match" => "3.5"})) ==
               wrap(%{"data.score" => %{"$lt" => 3.5}})
    end

    test "a non-numeric value for a numeric operator is dropped", %{conn: conn, project: project} do
      assert compiled_filter(conn, project, custom_form_data("gt", %{"key" => "age", "match" => "abc"})) ==
               %{"$or" => []}
    end

    test "is after / is before date compile to ISO 8601 $gt/$lt", %{conn: conn, project: project} do
      value = %{
        "key" => "signup",
        "date" => "2024-03-01",
        "time" => "10:30",
        "timezone" => "Etc/UTC"
      }

      assert compiled_filter(conn, project, custom_form_data("after", value)) ==
               wrap(%{"data.signup" => %{"$gt" => "2024-03-01T10:30:00Z"}})

      assert compiled_filter(conn, project, custom_form_data("before", value)) ==
               wrap(%{"data.signup" => %{"$lt" => "2024-03-01T10:30:00Z"}})
    end
  end

  describe "custom data operators — filter to form (round-trip)" do
    test "a numeric comparison filter opens in the visual editor", %{conn: conn, project: project} do
      {_view, html} = edit_live(conn, project, wrap(%{"data.age" => %{"$gt" => 40}}))

      refute html =~ "can only be edited manually"
      assert selected_widget(html) == ["gt"]
      assert input_value(html, "[value][key]") == ["age"]
      assert input_value(html, "[value][match]") == ["40"]
    end

    test "a $like filter opens with the includes operator", %{conn: conn, project: project} do
      {_view, html} = edit_live(conn, project, wrap(%{"data.city" => %{"$like" => "%erl%"}}))

      refute html =~ "can only be edited manually"
      assert selected_widget(html) == ["includes"]
      assert input_value(html, "[value][match]") == ["erl"]
    end

    test "a date comparison filter opens with the before operator", %{conn: conn, project: project} do
      {_view, html} =
        edit_live(conn, project, wrap(%{"data.signup" => %{"$lt" => "2024-03-01T00:00:00Z"}}))

      refute html =~ "can only be edited manually"
      assert selected_widget(html) == ["before"]
      assert input_value(html, "[value][key]") == ["signup"]
    end
  end
end
