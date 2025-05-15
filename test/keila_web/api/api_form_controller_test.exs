defmodule KeilaWeb.ApiFormControllerTest do
  use KeilaWeb.ApiCase, async: false
  use Oban.Testing, repo: Keila.Repo

  alias Keila.Contacts

  describe "GET /api/v1/forms" do
    @tag :api_form_controller
    test "lists forms", %{authorized_conn: conn, project: project} do
      n = 10
      insert_n!(:contacts_form, n, fn _n -> %{project_id: project.id} end)

      conn = get(conn, Routes.api_form_path(conn, :index))

      assert %{"data" => forms} = json_response(conn, 200)
      assert Enum.count(forms) == n
    end
  end

  describe "POST /api/v1/forms" do
    @tag :api_form_controller
    test "creates new form", %{authorized_conn: conn, project: project} do
      %{id: sender_id} = insert!(:mailings_sender, project_id: project.id)
      %{id: template_id} = insert!(:template, project_id: project.id)

      body = %{
        "data" => %{
          "name" => "Test Name",
          "sender_id" => sender_id,
          "template_id" => template_id,
          "settings" => %{
            "fine_print" => "This is the fine print"
          },
          "fields" => [
            %{
              "type" => "email",
              "cast" => true
            },
            %{
              "type" => "string",
              "cast" => true,
              "allowed_values" => [%{"label" => "Foo", "value" => "1"}]
            }
          ]
        }
      }

      conn = post_json(conn, Routes.api_form_path(conn, :create), body)

      assert %{"data" => %{"id" => id}} = json_response(conn, 200)

      assert %Contacts.Form{
               name: "Test Name",
               sender_id: ^sender_id,
               template_id: ^template_id,
               settings: %{
                 fine_print: "This is the fine print"
               },
               field_settings: [
                 %{
                   type: :email,
                   cast: true
                 },
                 %{
                   type: :string,
                   cast: true,
                   allowed_values: [%{label: "Foo", value: "1"}]
                 }
               ]
             } = Contacts.get_form(id)
    end
  end

  describe "GET /api/v1/forms/:id" do
    @tag :api_form_controller
    test "retrieves existing form", %{authorized_conn: conn, project: project} do
      %{id: id, name: name, field_settings: [%{field: :email}]} =
        insert!(:contacts_form, project_id: project.id)

      conn = get(conn, Routes.api_form_path(conn, :show, id))

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => ^name,
                 "fields" => [
                   %{"field" => "email"}
                 ]
               }
             } = json_response(conn, 200)
    end
  end

  describe "PATCH /api/v1/forms/:id" do
    @tag :api_form_controller
    test "updates existing form", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:contacts_form, project_id: project.id)

      body = %{
        "data" => %{
          "name" => "Updated Name",
          "settings" => %{"double_opt_in_required" => true},
          "fields" => [%{"field" => "data", "key" => "foo", "type" => "string"}]
        }
      }

      conn = patch_json(conn, Routes.api_form_path(conn, :update, id), body)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => "Updated Name",
                 "settings" => %{
                   "double_opt_in_required" => true
                 },
                 "fields" => [
                   %{"field" => "data", "key" => "foo", "type" => "string"}
                 ]
               }
             } = json_response(conn, 200)

      assert %{name: "Updated Name"} = Keila.Contacts.get_form(id)
    end

    @tag :api_form_controller
    test "also works when settings are not provided", %{authorized_conn: conn, project: project} do
      %{id: id} =
        insert!(:contacts_form, project_id: project.id, settings: %{double_opt_in_required: true})

      body = %{"data" => %{"name" => "Updated Name"}}
      conn = patch_json(conn, Routes.api_form_path(conn, :update, id), body)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => "Updated Name",
                 "settings" => %{
                   "double_opt_in_required" => true
                 }
               }
             } = json_response(conn, 200)

      assert %{name: "Updated Name"} = Keila.Contacts.get_form(id)
    end
  end

  describe "DELETE /api/v1/forms/:id" do
    @tag :api_form_controller
    test "always returns 204", %{authorized_conn: conn, project: project} do
      %{id: id} = insert!(:contacts_form, project_id: project.id)

      conn = delete(conn, Routes.api_form_path(conn, :delete, id))

      assert nil == Keila.Contacts.get_form(id)

      conn = delete(conn, Routes.api_form_path(conn, :delete, id))
      assert conn.status == 204
    end
  end

  describe "POST /api/v1/forms/:id/actions/submit" do
    @tag :api_form_controller
    test "creates Contact if DOI is not required", %{authorized_conn: conn, project: project} do
      form = insert!(:contacts_form, project_id: project.id)

      body = %{"data" => %{"email" => "test@example.com"}}
      conn = post_json(conn, Routes.api_form_path(conn, :submit, form.id), body)
      assert %{"id" => id, "email" => "test@example.com"} = json_response(conn, 200)["data"]
      assert %{email: "test@example.com"} = Keila.Contacts.get_project_contact(project.id, id)
    end

    @tag :api_form_controller
    test "creates FormParams if DOI required", %{authorized_conn: conn, project: project} do
      form =
        insert!(:contacts_form, project_id: project.id, settings: %{double_opt_in_required: true})

      email = "test@example.com"
      body = %{"data" => %{"email" => email}}
      conn = post_json(conn, Routes.api_form_path(conn, :submit, form.id), body)
      assert %{"double_opt_in_required" => true} == json_response(conn, 202)["data"]
      assert %{id: id, params: %{"email" => ^email}} = Keila.Repo.one(Keila.Contacts.FormParams)

      assert_enqueued(
        worker: Keila.Mailings.SendDoubleOptInMailWorker,
        args: %{"form_params_id" => id}
      )
    end
  end
end
