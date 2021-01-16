defmodule Keila.ContactsTest do
  use Keila.DataCase
  alias Keila.{Contacts, Contacts.Contact, Projects, Pagination}

  setup do
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
  test "Create contact with dynamic cast/validation options", %{project: project} do
    params = %{email: email, first_name: first_name} = build(:contact) |> Map.from_struct()

    {:ok, contact} = Contacts.create_contact(project.id, params, required: [:email])
    assert %Contact{email: ^email, first_name: nil, last_name: nil} = contact

    {:error, changeset} =
      Contacts.create_contact(project.id, Map.take(params, [:email]),
        required: [:email, :first_name]
      )

    assert [first_name: {_, [validation: :required]}] = changeset.errors

    {:ok, contact} =
      Contacts.create_contact(project.id, params, required: [:email], cast: [:first_name])

    assert %Contact{email: ^email, first_name: ^first_name, last_name: nil} = contact
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

    opts = [
      paginate: true,
      sort: %{"first_name" => -1},
      filter: %{"$or" => [%{"first_name" => "A"}, %{"first_name" => "E"}]}
    ]

    assert pagination = %Pagination{} = Contacts.get_project_contacts(project.id, opts)
    assert [contact5, contact1] == pagination.data
  end

  @tag :contacts
  test "delete_contact and delete_project_contacts", %{project: project} do
    contact1 = insert!(:contact, %{project_id: project.id})
    _contact2 = insert!(:contact, %{project_id: project.id})
    contact3 = insert!(:contact)

    assert :ok = Contacts.delete_project_contacts(project.id)
    assert nil == Contacts.get_contact(contact1.id)

    assert contact3 == Contacts.get_contact(contact3.id)
    assert :ok = Contacts.delete_contact(contact3.id)
    assert nil == Contacts.get_contact(contact3.id)
  end

  @import_names [
    {"Joël", "Müller-Schultheiß"},
    {"Eliška", "Þorláksson"}
  ]

  @tag :contacts
  test "Import RFC 4180 CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180.csv")
    assert_received {:contacts_import_progress, 0, 201}
    assert_received {:contacts_import_progress, 100, 201}
    assert_received {:contacts_import_progress, 200, 201}
    assert_received {:contacts_import_progress, 201, 201}

    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name} <- @import_names do
      assert Enum.find(contacts, fn
               %{first_name: ^first_name, last_name: ^last_name} -> true
               _ -> false
             end)
    end
  end

  @tag :contacts
  test "Import Excel TSV/CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_excel.csv")
    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name} <- @import_names do
      assert Enum.find(contacts, fn
               %{first_name: ^first_name, last_name: ^last_name} -> true
               _ -> false
             end)
    end
  end

  @tag :contacts
  test "Import LibreOffice CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_libreoffice.csv")
    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name} <- @import_names do
      assert Enum.find(contacts, fn
               %{first_name: ^first_name, last_name: ^last_name} -> true
               _ -> false
             end)
    end
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
