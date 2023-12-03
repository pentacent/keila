defmodule Keila.Contacts.ContactsFormParamsTest do
  use Keila.DataCase, async: true
  alias Keila.{Projects, Contacts}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))
    form = insert!(:contacts_form, project_id: project.id)

    %{form: form}
  end

  @params %{
    "email" => "test@example.com"
  }

  describe "create_form_params/2" do
    test "creates a new FormParams entity", %{form: form} do
      assert {:ok, form_params} = Contacts.create_form_params(form.id, @params)
      assert form_params.expires_at
      assert form_params.params == @params
    end
  end

  describe "get_form_params/1" do
    test "retrieves FormParams entity", %{form: form} do
      {:ok, form_params} = Contacts.create_form_params(form.id, @params)
      assert form_params == Contacts.get_form_params(form_params.id)
    end
  end

  describe "get_and_delete_form_params/1" do
    test "retrieves and deletes FormParams entity", %{form: form} do
      {:ok, form_params} = Contacts.create_form_params(form.id, @params)
      assert form_params == Contacts.get_and_delete_form_params(form_params.id)
      assert nil == Contacts.get_and_delete_form_params(form_params.id)
    end
  end

  describe "delete_form_params/1" do
    test "deletes FormParams entity", %{form: form} do
      {:ok, form_params} = Contacts.create_form_params(form.id, @params)
      assert :ok == Contacts.delete_form_params(form_params.id)
      refute form_params == Contacts.get_form_params(form_params.id)
      assert :ok == Contacts.delete_form_params(form_params.id)
    end
  end

  describe "double_opt_in_hmac/1 + valid_opt_in_hmac?/2" do
    test "HMAC is generated and validated", %{form: form} do
      {:ok, form_params} = Contacts.create_form_params(form.id, @params)
      hmac = Contacts.double_opt_in_hmac(form_params.id)

      assert Contacts.valid_double_opt_in_hmac?(hmac, form_params.id)
    end

    test "HMAC is unique per FormParams", %{form: form} do
      {:ok, form_params1} = Contacts.create_form_params(form.id, @params)
      hmac1 = Contacts.double_opt_in_hmac(form_params1.id)
      {:ok, form_params2} = Contacts.create_form_params(form.id, @params)
      hmac2 = Contacts.double_opt_in_hmac(form_params2.id)

      assert hmac1 != hmac2
      refute Contacts.valid_double_opt_in_hmac?(hmac1, form_params2.id)
      refute Contacts.valid_double_opt_in_hmac?(hmac2, form_params1.id)
    end
  end
end
