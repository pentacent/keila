defmodule Keila.ContactStatsTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Contacts}
  @moduletag :contacts

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  test "Contact stats", %{project: project} do
    insert!(:contact, project_id: project.id, status: :active)
    insert!(:contact, project_id: project.id, status: :active)
    insert!(:contact, project_id: project.id, status: :active)
    insert!(:contact, project_id: project.id, status: :unsubscribed)
    insert!(:contact, project_id: project.id, status: :unsubscribed)
    insert!(:contact, project_id: project.id, status: :unreachable)

    assert %{
             active: 3,
             unsubscribed: 2,
             unreachable: 1
           } == Contacts.get_project_contacts_stats(project.id)
  end
end
