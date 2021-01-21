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
    forms = insert_n!(:contacts_form, 5, fn _n -> %{project_id: project.id} end)
    assert forms == Contacts.get_project_forms(project.id)
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
          "label" => "Enter your email here"
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
                 field: "email",
                 label: "Enter your email here"
               }
             ]
           } = form
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
