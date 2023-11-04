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

  describe "double_opt_in_hmac/1 + valid_opt_in_hmac?/2" do
    test "HMAC is generated and validated", %{form: form} do
      {:ok, form_attrs} = Contacts.create_form_attrs(form.id, @attrs)
      hmac = Contacts.double_opt_in_hmac(form_attrs.id)

      assert Contacts.valid_double_opt_in_hmac?(hmac, form_attrs.id)
    end

    test "HMAC is unique per FormAttrs", %{form: form} do
      {:ok, form_attrs1} = Contacts.create_form_attrs(form.id, @attrs)
      hmac1 = Contacts.double_opt_in_hmac(form_attrs1.id)
      {:ok, form_attrs2} = Contacts.create_form_attrs(form.id, @attrs)
      hmac2 = Contacts.double_opt_in_hmac(form_attrs2.id)

      assert hmac1 != hmac2
      refute Contacts.valid_double_opt_in_hmac?(hmac1, form_attrs2.id)
      refute Contacts.valid_double_opt_in_hmac?(hmac2, form_attrs1.id)
    end
  end
end
