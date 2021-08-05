defmodule Keila.ContactsEventsAndStatusTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Contacts, Contacts.Event}
  @moduletag :contacts

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  test "Log contact events", %{project: project} do
    %{id: contact_id} = insert!(:contact, project_id: project.id)
    assert {:ok, _} = Contacts.log_event(contact_id, "open")
    assert {:ok, _} = Contacts.log_event(contact_id, "click")
    assert {:ok, _} = Contacts.log_event(contact_id, "unsubscribe")

    events = Contacts.get_contact_events(contact_id)

    assert Enum.count(events) == 3

    assert Enum.find(
             events,
             &match?(%Event{type: :unsubscribe, contact_id: ^contact_id, data: %{}}, &1)
           )

    assert Enum.find(
             events,
             &match?(%Event{type: :click, contact_id: ^contact_id, data: %{}}, &1)
           )

    assert Enum.find(
             events,
             &match?(%Event{type: :open, contact_id: ^contact_id, data: %{}}, &1)
           )
  end

  test "Logging contact events updates contact status", %{project: project} do
    contact = insert!(:contact, project_id: project.id)
    assert contact.status == :active

    Contacts.log_event(contact.id, "hard_bounce")
    assert Contacts.get_contact(contact.id).status == :unreachable

    Contacts.log_event(contact.id, "unsubscribe")
    assert Contacts.get_contact(contact.id).status == :unsubscribed
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
