defmodule Keila.ContactsFormTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Contacts, Contacts.Form}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :contacts_form
  test "List forms", %{project: project} do
    forms =
      insert_n!(:contacts_form, 5, fn _n -> %{project_id: project.id} end)
      |> Enum.sort_by(& &1.id)

    assert forms == Contacts.get_project_forms(project.id) |> Enum.sort_by(& &1.id)
  end

  @tag :contacts_form
  test "Create form", %{project: project} do
    params = %{
      "name" => "My Form",
      "settings" => %{
        "captcha_required" => true
      },
      "field_settings" => [
        %{
          "field" => "email",
          "label" => "Enter your email here",
          "required" => true
        }
      ]
    }

    assert {:ok, form} = Contacts.create_form(project.id, params)

    assert %Form{
             name: "My Form",
             settings: %Form.Settings{
               captcha_required: true
             },
             field_settings: [
               %Form.FieldSettings{
                 field: :email,
                 label: "Enter your email here",
                 cast: true,
                 required: true
               }
             ]
           } = form
  end

  @tag :contacts_form
  test "Email field must be cast and required", %{project: project} do
    params = %{"name" => "My Form", "field_settings" => [%{"field" => "email"}]}

    assert {:error, changeset} = Contacts.create_form(project.id, params)
    assert [field_settings: {"email field must be cast and required", _}] = changeset.errors
  end

  @tag :contacts_form
  test "Form requires an email field", %{project: project} do
    params = %{"name" => "My Form", "field_settings" => [%{"field" => "first_name"}]}

    assert {:error, changeset} = Contacts.create_form(project.id, params)
    assert [field_settings: {"must include an email field", _}] = changeset.errors
  end

  @tag :contacts_form
  test "Data fields must have unique keys", %{project: project} do
    params = %{
      "name" => "My Form",
      "field_settings" => [
        %{"field" => "email", "required" => true},
        %{"field" => "data", "key" => "pet", "type" => "string"},
        %{"field" => "data", "key" => "pet", "type" => "string"},
        %{"field" => "data", "type" => "string"},
        %{"field" => "data", "type" => "string"}
      ]
    }

    assert {:error, changeset} = Contacts.create_form(project.id, params)

    assert %{
             field_settings: [
               %{},
               %{key: ["has already been taken"]},
               %{key: ["has already been taken"]},
               %{key: ["can't be blank"]},
               %{key: ["can't be blank"]}
             ]
           } = errors_on(changeset)
  end

  @tag :contacts_form
  test "Update form", %{project: project} do
    form = insert!(:contacts_form, project_id: project.id)
    assert {:ok, form} = Contacts.update_form(form.id, %{"name" => "Updated Form"})
    assert form.name == "Updated Form"
  end

  @tag :contacts_form
  test "Delete form", %{project: project} do
    form = insert!(:contacts_form, project_id: project.id)
    assert :ok == Contacts.delete_form(form.id)
    assert nil == Contacts.get_form(form.id)
  end
end
