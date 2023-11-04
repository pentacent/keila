defmodule Keila.Contacts.ContactsFormAttrsTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Contacts}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))
    form = insert!(:contacts_form, project_id: project.id)

    %{form: form}
  end

  @attrs %{
    "email" => "test@example.com"
  }

  describe "create_form_attrs/2" do
    test "creates a new FormAttrs entity", %{form: form} do
      assert {:ok, form_attrs} = Contacts.create_form_attrs(form.id, @attrs)
      assert form_attrs.expires_at
      assert form_attrs.attrs == @attrs
    end
  end

  describe "get_form_attrs/1" do
    test "retrieves FormAttrs entity", %{form: form} do
      {:ok, form_attrs} = Contacts.create_form_attrs(form.id, @attrs)
      assert form_attrs == Contacts.get_form_attrs(form_attrs.id)
    end
  end

  describe "get_and_delete_form_attrs/1" do
    test "retrieves and deletes FormAttrs entity", %{form: form} do
      {:ok, form_attrs} = Contacts.create_form_attrs(form.id, @attrs)
      assert form_attrs == Contacts.get_and_delete_form_attrs(form_attrs.id)
      assert nil == Contacts.get_and_delete_form_attrs(form_attrs.id)
    end
  end

  describe "delete_form_attrs/1" do
    test "deletes FormAttrs entity", %{form: form} do
      {:ok, form_attrs} = Contacts.create_form_attrs(form.id, @attrs)
      assert :ok == Contacts.delete_form_attrs(form_attrs.id)
      refute form_attrs == Contacts.get_form_attrs(form_attrs.id)
      assert :ok == Contacts.delete_form_attrs(form_attrs.id)
    end
  end
end
