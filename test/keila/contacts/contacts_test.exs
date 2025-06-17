defmodule Keila.ContactsTest do
  use Keila.DataCase, async: true
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
  test "Contact emails are case-insensitive", %{project: project} do
    assert {:ok, contact1} = Contacts.create_contact(project.id, params(:contact))

    assert {:error, _} =
             Contacts.create_contact(
               project.id,
               params(:contact, email: String.upcase(contact1.email))
             )

    assert {:error, _} =
             Contacts.create_contact(
               project.id,
               params(:contact, email: String.downcase(contact1.email))
             )
  end

  @tag :contacts
  test "first_name and last_name are limited to 50 characters", %{project: project} do
    assert {:error, _changeset} =
             Contacts.create_contact(
               project.id,
               params(:contact,
                 first_name: "This is not a real first name it's actually spam!!!"
               )
             )

    assert {:error, _changeset} =
             Contacts.create_contact(
               project.id,
               params(:contact,
                 last_name: "This is not actually a genuine last name it's spam!!!"
               )
             )
  end

  @tag :contacts
  test "Create contact with dynamic cast/validation options from form", %{project: project} do
    params = %{email: email, first_name: _} = build(:contact) |> Map.from_struct()

    form = insert!(:contacts_form, project_id: project.id)
    {:ok, contact} = Contacts.perform_form_action(form, params)
    assert %Contact{email: ^email, first_name: nil, last_name: nil} = contact

    form =
      insert!(:contacts_form,
        project_id: project.id,
        field_settings: [
          %{field: :email, cast: true, required: true},
          %{field: :first_name, cast: true, required: true}
        ]
      )

    params = %{email: email, first_name: first_name} = build(:contact) |> Map.from_struct()

    assert {:error, changeset} =
             Contacts.perform_form_action(form, Map.take(params, [:email]))

    assert [first_name: {_, [validation: :required]}] = changeset.errors

    assert {:ok, contact} = Contacts.perform_form_action(form, params)

    assert %Contact{email: ^email, first_name: ^first_name, last_name: nil} = contact
  end

  @tag :contacts
  test "Edit contact", %{project: project} do
    contact = insert!(:contact, %{project_id: project.id})
    params = params(:contact)
    assert {:ok, updated_contact = %Contact{}} = Contacts.update_contact(contact.id, params)
    assert updated_contact.email == params["email"]
  end

  @tag :double_opt_in
  test "Not changing the contact email keeps the double_opt_in_at value", %{project: project} do
    contact =
      insert!(:contact, %{project_id: project.id, double_opt_in_at: DateTime.utc_now(:second)})

    params = params(:contact) |> Map.delete("email")
    assert {:ok, updated_contact = %Contact{}} = Contacts.update_contact(contact.id, params)
    assert updated_contact.first_name == params["first_name"]
    assert updated_contact.double_opt_in_at
  end

  @tag :double_opt_in
  test "Editing an email address removes the double_opt_in_at value", %{project: project} do
    contact =
      insert!(:contact, %{project_id: project.id, double_opt_in_at: DateTime.utc_now(:second)})

    assert contact.double_opt_in_at
    params = params(:contact)
    assert {:ok, updated_contact = %Contact{}} = Contacts.update_contact(contact.id, params)
    assert updated_contact.email == params["email"]
    refute updated_contact.double_opt_in_at
  end

  @tag :contacts
  test "Get project contact by ID, email, and external ID", %{project: project} do
    contact1 = insert!(:contact, %{project_id: project.id})
    contact2 = insert!(:contact, %{project_id: project.id})
    contact3 = insert!(:contact, %{project_id: project.id, external_id: "ext"})

    assert contact1 == Contacts.get_project_contact(contact1.project_id, contact1.id)
    assert contact2 == Contacts.get_project_contact_by_email(contact2.project_id, contact2.email)

    assert contact3 ==
             Contacts.get_project_contact_by_external_id(
               contact3.project_id,
               contact3.external_id
             )
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

  @imported_contacts [
    {"Joël", "Müller-Schultheiß", %{"foo" => "bar"}},
    {"Eliška", "Þorláksson", %{"foo" => [1, 2, 3]}}
  ]

  @tag :contacts
  test "Import RFC 4180 CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180.csv")
    assert_received {:contacts_import_progress, 0, 201}
    assert_received {:contacts_import_progress, 100, 201}
    assert_received {:contacts_import_progress, 200, 201}
    assert_received {:contacts_import_progress, 201, 201}

    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name, _data} <- @imported_contacts do
      assert Enum.find(contacts, fn
               %{first_name: ^first_name, last_name: ^last_name} -> true
               _ -> false
             end)
    end
  end

  @tag :contacts
  test "Import RFC 4180 CSV with on_conflict: replace (upsert)", %{project: project} do
    assert :ok ==
             Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180_upsert.csv",
               on_conflict: :replace
             )

    contacts = Contacts.get_project_contacts(project.id)

    expected = [
      %{first_name: "João", last_name: "Nilton"},
      %{first_name: "Elisa", last_name: "Paula"},
      %{first_name: "Foo", last_name: "Bar"}
    ]

    for %{first_name: e_fn, last_name: e_ln} <- expected do
      assert Enum.find(contacts, fn
               %{first_name: ^e_fn, last_name: ^e_ln} -> true
               _ -> false
             end)
    end

    refute Enum.find(contacts, fn
             %{first_name: "João", last_name: "Milton"} -> true
             _ -> false
           end)
  end

  @tag :contacts
  test "Import RFC 4180 CSV with on_conflict: ignore", %{project: project} do
    assert :ok ==
             Contacts.import_csv(project.id, "test/keila/contacts/import_rfc_4180_upsert.csv",
               on_conflict: :ignore
             )

    contacts = Contacts.get_project_contacts(project.id)

    expected = [
      %{first_name: "João", last_name: "Milton"},
      %{first_name: "Elisa", last_name: "Paula"},
      %{first_name: "Foo", last_name: "Bar"}
    ]

    for %{first_name: e_fn, last_name: e_ln} <- expected do
      assert Enum.find(contacts, fn
               %{first_name: ^e_fn, last_name: ^e_ln} -> true
               _ -> false
             end)
    end

    refute Enum.find(contacts, fn
             %{first_name: "João", last_name: "Nilton"} -> true
             _ -> false
           end)
  end

  @tag :contacts
  test "Import RFC 4180 CSV with data", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_with_data.csv")
    assert_received {:contacts_import_progress, 2, 2}

    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name, data} <- @imported_contacts do
      assert Enum.find(contacts, fn
               %{first_name: ^first_name, last_name: ^last_name, data: ^data} -> true
               _ -> false
             end)
    end
  end

  @tag :contacts
  test "Import RFC 4180 CSV with status column", %{project: project} do
    assert :ok ==
             Contacts.import_csv(
               project.id,
               "test/keila/contacts/import_rfc_4180_with_status.csv"
             )

    assert_received {:contacts_import_progress, 1, 4}

    assert Repo.get_by(Contacts.Contact, email: "active@example.com")
    refute Repo.get_by(Contacts.Contact, email: "unsubscribed@example.com")
    refute Repo.get_by(Contacts.Contact, email: "unreachable@example.com")
    refute Repo.get_by(Contacts.Contact, email: "empty@example.com")
  end

  @tag :contacts
  test "Import RFC 4180 CSV with external IDs and on_conflict: :ignore", %{project: project} do
    assert :ok ==
             Contacts.import_csv(
               project.id,
               "test/keila/contacts/import_external_ids.csv",
               on_conflict: :ignore
             )

    contacts = Contacts.get_project_contacts(project.id)

    expected = [
      %{email: "foo@example.com", external_id: nil},
      %{email: "foo2@example.com", external_id: "1"},
      %{email: "foo3@example.com", external_id: "3"}
    ]

    for %{email: email, external_id: external_id} <- expected do
      assert Enum.find(contacts, fn
               %{email: ^email, external_id: ^external_id} -> true
               _ -> false
             end)
    end

    assert length(contacts) == length(expected)
  end

  @tag :contacts
  test "Import CSV with external IDs and on_conflict: :replace", %{project: project} do
    assert :ok ==
             Contacts.import_csv(
               project.id,
               "test/keila/contacts/import_external_ids.csv",
               on_conflict: :replace
             )

    contacts = Contacts.get_project_contacts(project.id)

    expected = [
      %{email: "foo2@example.com", external_id: "1"},
      %{email: "foo3@example.com", external_id: "3"}
    ]

    for %{email: email, external_id: external_id} <- expected do
      assert Enum.find(contacts, fn
               %{email: ^email, external_id: ^external_id} -> true
               _ -> false
             end)
    end

    assert length(contacts) == length(expected)
  end

  @tag :contacts
  test "Gracefully handle duplicates with external IDs and on_conflict: :replace", %{
    project: project
  } do
    assert {:error, message} =
             Contacts.import_csv(
               project.id,
               "test/keila/contacts/import_external_ids_duplicate.csv",
               on_conflict: :replace
             )

    assert message =~ "duplicate entry"

    assert Enum.empty?(Contacts.get_project_contacts(project.id))
  end

  @tag :contacts
  test "Import Excel TSV/CSV", %{project: project} do
    assert :ok == Contacts.import_csv(project.id, "test/keila/contacts/import_excel.csv")
    contacts = Contacts.get_project_contacts(project.id)

    for {first_name, last_name, _data} <- @imported_contacts do
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

    for {first_name, last_name, _data} <- @imported_contacts do
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

  @tag :contacts
  test "custom data is limited to 8 KB", %{project: project} do
    params = params(:contact)
    data = %{"foo" => String.pad_trailing("", 7_000, "bar")}
    valid_params = Map.put(params, "data", data)
    assert {:ok, _} = Contacts.create_contact(project.id, valid_params)

    params = params(:contact)
    data = %{"foo" => String.pad_trailing("", 9_000, "bar")}
    invalid_params = Map.put(params, "data", data)
    assert {:error, changeset} = Contacts.create_contact(project.id, invalid_params)
    assert %{errors: [data: {"max 8 KB data allowed", _}]} = changeset
  end

  @tag :contacts
  test "Update contact with status when update_status option is true", %{project: project} do
    contact = insert!(:contact, %{project_id: project.id, status: :active})
    params = %{"status" => "unsubscribed", "first_name" => "Updated"}
    
    assert {:ok, updated_contact} = Contacts.update_contact(contact.id, params, update_status: true)
    assert updated_contact.status == :unsubscribed
    assert updated_contact.first_name == "Updated"
  end

  @tag :contacts
  test "Update contact ignores status when update_status option is false", %{project: project} do
    contact = insert!(:contact, %{project_id: project.id, status: :active})
    params = %{"status" => "unsubscribed", "first_name" => "Updated"}
    
    assert {:ok, updated_contact} = Contacts.update_contact(contact.id, params, update_status: false)
    assert updated_contact.status == :active  # Status should remain unchanged
    assert updated_contact.first_name == "Updated"
  end

  @tag :contacts
  test "Update contact ignores status when update_status option is not provided", %{project: project} do
    contact = insert!(:contact, %{project_id: project.id, status: :active})
    params = %{"status" => "unsubscribed", "first_name" => "Updated"}
    
    assert {:ok, updated_contact} = Contacts.update_contact(contact.id, params)
    assert updated_contact.status == :active  # Status should remain unchanged
    assert updated_contact.first_name == "Updated"
  end

  @tag :contacts
  test "Create contact with status when set_status option is true", %{project: project} do
    params = params(:contact) |> Map.put("status", "unsubscribed")
    
    assert {:ok, contact} = Contacts.create_contact(project.id, params, set_status: true)
    assert contact.status == :unsubscribed
  end

  @tag :contacts
  test "Create contact ignores status when set_status option is false", %{project: project} do
    params = params(:contact) |> Map.put("status", "unsubscribed")
    
    assert {:ok, contact} = Contacts.create_contact(project.id, params, set_status: false)
    assert contact.status == :active  # Should default to active
  end

  @tag :contacts
  test "Create contact ignores status when set_status option is not provided", %{project: project} do
    params = params(:contact) |> Map.put("status", "unsubscribed")
    
    assert {:ok, contact} = Contacts.create_contact(project.id, params)
    assert contact.status == :active  # Should default to active
  end
end
