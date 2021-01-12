defmodule Keila.ContactsTest do
  use ExUnit.Case, async: true
  import Keila.Factory

  alias Keila.{Contacts, Projects, Pagination, Repo}
  alias Contacts.Contact

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :contacts
  test "Create contact", %{project: project} do
    assert {:ok, %Contact{}} = Contacts.create_contact(project.id, params(:contact))
  end

  @tag :contacts
  test "Edit contact", %{project: project} do
    contact = insert!(:contact, %{project_id: project.id})
    params = params(:contact)
    assert {:ok, updated_contact = %Contact{}} = Contacts.update_contact(contact.id, params)
    assert updated_contact.email == params["email"]
  end

  @tag :contacts
  test "List project contacts", %{project: project} do
    contact1 = insert!(:contact, %{project_id: project.id})
    contact2 = insert!(:contact, %{project_id: project.id})
    _contact3 = insert!(:contact)

    assert contacts = [%Contact{}, %Contact{}] = Contacts.get_project_contacts(project.id)
    assert contact1 in contacts
    assert contact2 in contacts
  end

  @tag :contacts
  test "Query and pagination options are available in get_project_contacts", %{project: project} do
    contact1 = insert!(:contact, %{project_id: project.id, first_name: "A"})
    _contact2 = insert!(:contact, %{project_id: project.id, first_name: "B"})
    _contact3 = insert!(:contact, %{project_id: project.id, first_name: "C"})
    _contact4 = insert!(:contact, %{project_id: project.id, first_name: "D"})
    contact5 = insert!(:contact, %{project_id: project.id, first_name: "E"})
    _contact6 = insert!(:contact)

    opts = [paginate: true, sort: %{"first_name" => -1}, filter: %{"$or" => [%{"first_name" => "A"}, %{"first_name" => "E"}]}]
    assert pagination = %Pagination{} = Contacts.get_project_contacts(project.id, opts)
    assert [contact5, contact1] == pagination.data
  end

  @tag :contacts_import
  test "Import CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import.csv")
    assert_received {:contacts_import_progress, 0, 201}
    assert_received {:contacts_import_progress, 100, 201}
    assert_received {:contacts_import_progress, 200, 201}
    assert_received {:contacts_import_progress, 201, 201}
    # assert [%Contact{}, %Contact{}, %Contact{}] = Contacts.get_project_contacts(project.id)
  end

  @tag :contacts
  test "Human-readable CSV error messages", %{project: project} do
    assert {:error, message} =
             Contacts.import_csv(project.id, "test/keila/contacts/import_malformed1.csv")

    assert message =~ "unexpected escape character"

    assert {:error, message} =
             Contacts.import_csv(project.id, "test/keila/contacts/import_malformed2.csv")

    assert message =~ "Field email: can't be blank"
  end
end
