defmodule KeilaWeb.ContactControllerTest do
  use KeilaWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint KeilaWeb.Endpoint

  @tag :contact_controller
  test "GET /projects/:p_id/contacts", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    contacts = insert_n!(:contact, 2, fn _ -> %{project_id: project.id} end)
    conn = get(conn, Routes.contact_path(conn, :index, project.id))

    html_response = html_response(conn, 200)
    assert html_response =~ ~r{Contacts\s*</h1>}
    for contact <- contacts, do: assert(html_response =~ contact.email)
  end

  @tag :contact_controller
  test "GET /projects/:p_id/contacts empty state", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    conn = get(conn, Routes.contact_path(conn, :index, project.id))
    assert html_response(conn, 200) =~ ~r{Ready to get started?}
  end

  @tag :contact_controller
  test "GET /projects/:p_id/contacts/new", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    conn = get(conn, Routes.contact_path(conn, :new, project.id))
    assert html_response(conn, 200) =~ ~r{New Contact}
  end

  @tag :contact_controller
  test "POST /projects/:p_id/contacts/new", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    params = params(:contact)
    conn = post(conn, Routes.contact_path(conn, :new, project.id, contact: params))
    assert redirected_to(conn, 302) == Routes.contact_path(conn, :index, project.id)
    conn = get(conn, Routes.contact_path(conn, :index, project.id))
    assert html_response(conn, 200) =~ params["email"]
  end

  @tag :contact_controller
  test "GET /projects/:p_id/contacts/:id", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    contact = insert!(:contact, project_id: project.id)
    conn = get(conn, Routes.contact_path(conn, :edit, project.id, contact.id))
    assert html_response(conn, 200) =~ ~r{#{contact.email}\s*</h1>}
  end

  @tag :contact_controller
  test "PUT /projects/:p_id/contacts/:id", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    contact = insert!(:contact, project_id: project.id)

    conn =
      put(
        conn,
        Routes.contact_path(conn, :post_edit, project.id, contact.id,
          contact: %{"email" => "updated@example.com"}
        )
      )

    assert redirected_to(conn, 302) == Routes.contact_path(conn, :index, project.id)
    assert %{email: "updated@example.com"} = Keila.Contacts.get_contact(contact.id)
  end

  @tag :contact_controller
  test "DELETE /projects/:p_id/contacts", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    contact = insert!(:contact, project_id: project.id)

    conn =
      delete(
        conn,
        Routes.contact_path(conn, :delete, project.id, %{"contact" => %{"id" => [contact.id]}})
      )

    assert redirected_to(conn, 302) == Routes.contact_path(conn, :index, project.id)
    assert nil == Keila.Contacts.get_contact(contact.id)
  end

  @tag :contact_controller
  test "DELETE /projects/:p_id/contacts with confirmation", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    contact = insert!(:contact, project_id: project.id)

    conn =
      delete(
        conn,
        Routes.contact_path(conn, :delete, project.id, %{
          "contact" => %{"require_confirmation" => "true", "id" => [contact.id]}
        })
      )

    assert html_response(conn, 200) =~ ~r{Delete Contacts\?\s*</h1>}
    assert contact == Keila.Contacts.get_contact(contact.id)
  end

  @tag :contact_controller
  test "LV /projects/:p_id/import", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    conn = get(conn, Routes.contact_path(conn, :import, project.id))
    assert html_response(conn, 200) =~ ~r{Import Contacts\s*</h1>}

    {:ok, _view, html} = live(conn)
    assert html =~ ~r{Import Contacts\s*</h1>}
  end

  @tag :contact_controller
  test "LV /projects/:p_id/import CSV upload", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    conn = get(conn, Routes.contact_path(conn, :import, project.id))
    {:ok, lv, _html} = live(conn)

    import_file = "test/keila/contacts/import_rfc_4180.csv"

    csv =
      file_input(lv, "#import-form", :csv, [
        %{
          last_modified: 1_594_171_879_000,
          name: "import.csv",
          content: File.read!(import_file),
          size: File.stat!(import_file).size,
          type: "text/csv"
        }
      ])

    assert render_upload(csv, "import.csv") =~ "100%"

    lv
    |> element("#import-form")
    |> render_submit(%{csv: csv})

    assert Keila.Contacts.get_project_contacts(project.id) |> Enum.count() == 201
    assert render(lv) =~ "You have successfully imported 201 contacts!"
  end
end
