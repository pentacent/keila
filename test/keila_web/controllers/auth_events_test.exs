defmodule KeilaWeb.AuthEventsTest do
  use KeilaWeb.ConnCase
  import Ecto.Query
  alias Keila.{Auth, Repo}
  alias Keila.Auth.Event

  @password "BatteryHorseStaple"
  @valid_hcaptcha "10000000-aaaa-bbbb-cccc-000000000001"

  defp events(type) do
    from(e in Event, where: e.type == ^type, order_by: e.inserted_at) |> Repo.all()
  end

  @tag :auth_events
  test "logs logins with IP and user agent", %{conn: conn} do
    {_root, user} = with_seed()
    user_id = user.id

    conn
    |> put_req_header("user-agent", "Peter's Browser")
    |> post(Routes.auth_path(conn, :login), user: %{email: user.email, password: @password})

    assert [
             %Event{
               user_id: ^user_id,
               ip: {127, 0, 0, 1},
               data: %{"user_agent" => "Peter's Browser"}
             }
           ] = events(:login)
  end

  @tag :auth_events
  test "replaces invalid characters in the user agent", %{conn: conn} do
    {_root, user} = with_seed()

    conn =
      conn
      |> put_req_header("user-agent", "Peter\xFF\xFE")
      |> post(Routes.auth_path(conn, :login), user: %{email: user.email, password: @password})

    assert redirected_to(conn, 302)
    assert [%Event{data: %{"user_agent" => user_agent}}] = events(:login)
    assert user_agent == "Peter" <> String.duplicate(<<0xFFFD::utf8>>, 2)
  end

  @tag :auth_events
  test "logs failed logins without storing the email address", %{conn: conn} do
    {_root, user} = with_seed()
    user_id = user.id

    post(conn, Routes.auth_path(conn, :login), user: %{email: user.email, password: "wrong"})

    post(conn, Routes.auth_path(conn, :login),
      user: %{email: "stewie@example.com", password: "wrong"}
    )

    assert [%Event{user_id: ^user_id}, %Event{user_id: nil, data: data}] =
             events(:login_failed)

    refute inspect(data) =~ "stewie@example.com"
  end

  @tag :auth_events
  test "logs logouts", %{conn: conn} do
    conn = with_login(conn)
    user_id = conn.assigns.current_user.id

    get(conn, Routes.auth_path(conn, :logout))

    assert [%Event{user_id: ^user_id}] = events(:logout)
  end

  @tag :auth_events
  test "logs registrations", %{conn: conn} do
    with_seed()

    post(conn, Routes.auth_path(conn, :register),
      user: %{"email" => "lois@example.com", "password" => @password},
      "h-captcha-response": @valid_hcaptcha
    )

    user = Auth.find_user_by_email("lois@example.com")
    user_id = user.id
    assert [%Event{user_id: ^user_id}] = events(:register)
  end

  @tag :auth_events
  test "logs password reset requests for known and unknown email addresses", %{conn: conn} do
    {_root, user} = with_seed()
    user_id = user.id

    for email <- [user.email, "stewie@example.com"] do
      post(conn, Routes.auth_path(conn, :reset),
        user: %{email: email},
        "h-captcha-response": @valid_hcaptcha
      )
    end

    assert [%Event{user_id: ^user_id}, %Event{user_id: nil}] = events(:request_password_reset)
  end

  @tag :auth_events
  test "logs password changes via reset link", %{conn: conn} do
    user = insert!(:user)
    user_id = user.id
    {:ok, %{key: key}} = Auth.create_token(%{user_id: user.id, scope: "auth.reset"})

    post(conn, Routes.auth_path(conn, :reset_change_password, key),
      user: %{"password" => "NewSecurePassword123"}
    )

    assert [%Event{user_id: ^user_id}] = events(:reset_password)
  end

  @tag :auth_events
  test "logs password changes on the account page", %{conn: conn} do
    conn = with_login(conn)
    user_id = conn.assigns.current_user.id

    put(conn, Routes.account_path(conn, :post_edit), user: %{"password" => "MyNewPassword"})

    assert [%Event{user_id: ^user_id}] = events(:change_password)
  end

  @tag :auth_events
  test "logs creating and deleting API keys", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    user_id = conn.assigns.current_user.id
    project_id = project.id

    post(conn, Routes.api_key_path(conn, :create, project.id, %{"api_key" => %{"name" => "Foo"}}))
    [%{id: api_key_id}] = Auth.get_user_project_api_keys(user_id, project.id)

    delete(conn, Routes.api_key_path(conn, :delete, project.id, api_key_id))

    assert [
             %Event{
               user_id: ^user_id,
               data: %{"api_key_id" => ^api_key_id, "project_id" => ^project_id}
             }
           ] = events(:create_api_key)

    assert [
             %Event{
               user_id: ^user_id,
               data: %{"api_key_id" => ^api_key_id, "project_id" => ^project_id}
             }
           ] = events(:delete_api_key)
  end

  @tag :auth_events
  test "logs failed API authentication with an invalid key", %{conn: conn} do
    with_seed()

    conn
    |> put_req_header("authorization", "Bearer invalid-key")
    |> get(Routes.api_contact_path(conn, :index))

    assert [%Event{user_id: nil, ip: {127, 0, 0, 1}}] = events(:authenticate_api_failed)
  end

  @tag :auth_events
  test "logs impersonation for the impersonated user", %{conn: conn} do
    {root, user} = with_seed()
    conn = with_login(conn, user: root)
    root_id = root.id
    user_id = user.id

    post(conn, Routes.user_admin_path(conn, :impersonate, user.id))

    assert [%Event{user_id: ^user_id, actor_id: ^root_id}] = events(:impersonate)
  end
end
