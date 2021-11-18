defmodule Keila.ContactsSegmentsTest do
  use Keila.DataCase, async: true
  alias Keila.{Contacts, Contacts.Segment, Projects}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :contacts_segments
  test "Create segment", %{project: project} do
    assert {:ok, %Segment{}} = Contacts.create_segment(project.id, params(:contacts_segment))
  end

  @tag :contacts_segments
  test "Edit segment", %{project: project} do
    segment = insert!(:contacts_segment, %{project_id: project.id})
    params = params(:contacts_segment, %{filter: %{"email" => "foo@bar.com"}})
    assert {:ok, updated_segment = %Segment{}} = Contacts.update_segment(segment.id, params)
    assert updated_segment.filter == params["filter"]
  end

  @tag :contacts_segments
  test "List project segments", %{project: project} do
    segment1 = insert!(:contacts_segment, %{project_id: project.id})
    segment2 = insert!(:contacts_segment, %{project_id: project.id})
    _segment3 = insert!(:contacts_segment)

    assert segments = [%Segment{}, %Segment{}] = Contacts.get_project_segments(project.id)
    assert segment1 in segments
    assert segment2 in segments
  end

  @tag :contacts_segments
  test "delete_segment and delete_project_segments", %{project: project} do
    segment1 = insert!(:contacts_segment, %{project_id: project.id})
    segment2 = insert!(:contacts_segment, %{project_id: project.id})
    segment3 = insert!(:contacts_segment)

    assert :ok =
             Contacts.delete_project_segments(project.id, [segment1.id, segment2.id, segment3.id])

    assert Contacts.get_project_segments(project.id) == []
    assert segment3 == Contacts.get_segment(segment3.id)

    assert segment3 == Contacts.get_segment(segment3.id)
    assert :ok = Contacts.delete_segment(segment3.id)
    assert nil == Contacts.get_segment(segment3.id)
  end
end
