defmodule KeilaWeb.SenderControllerTest do
  use KeilaWeb.ConnCase

  @tag :sender_controller
  test "index senders", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    senders = insert_n!(:mailings_sender, 2, fn _ -> %{project_id: project.id} end)

    conn = get(conn, Routes.sender_path(conn, :index, project.id))
    html_response = html_response(conn, 200)
    assert html_response =~ ~r{Senders\s*</h1>}
    for sender <- senders, do: assert(html_response =~ sender.name)
  end

  @tag :sender_controller
  test "new sender form", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    conn = get(conn, Routes.sender_path(conn, :new, project.id))

    assert html_response(conn, 200) =~ ~r{New Sender\s*</h1>}
  end

  @tag :sender_controller
  test "post new sender form", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)

    incomplete_params = %{name: "My Sender"}
    conn = post(conn, Routes.sender_path(conn, :create, project.id, sender: incomplete_params))
    assert html_response(conn, 400)

    params = params(:mailings_sender)
    conn = post(conn, Routes.sender_path(conn, :create, project.id, sender: params))
    redirected_path = redirected_to(conn, 302)
    conn = get(conn, redirected_path)

    assert html_response(conn, 200) =~ params["name"]
  end

  @tag :sender_controller
  test "show/edit sender form", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    conn = get(conn, Routes.sender_path(conn, :edit, project.id, sender.id))
    assert html_response(conn, 200) =~ ~r{#{sender.name}\s*</h1>}
  end

  @tag :sender_controller
  test "submit edit sender form", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    params =
      params(:mailings_sender, %{project_id: project.id})
      |> put_in(["config", "id"], sender.config.id)

    conn = put(conn, Routes.sender_path(conn, :update, project.id, sender.id, sender: params))
    assert redirected_to(conn, 302) == Routes.sender_path(conn, :index, project.id)
    updated_sender = Keila.Mailings.get_sender(sender.id)
    assert updated_sender.name == params["name"]
  end

  @tag :sender_controller
  test "show delete sender form", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    conn = get(conn, Routes.sender_path(conn, :delete_confirmation, project.id, sender.id))
    assert html_response(conn, 200) =~ ~r{Delete Sender #{sender.name}\?\s*</h1>}
  end

  @tag :sender_controller
  test "deleting sender requires confirmation", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id, shared_sender: nil})

    conn = delete(conn, Routes.sender_path(conn, :delete, project.id, sender.id), sender: %{})
    assert html_response(conn, 400)
    assert sender == Keila.Mailings.get_sender(sender.id)

    conn =
      delete(conn, Routes.sender_path(conn, :delete, project.id, sender.id),
        sender: %{delete_confirmation: sender.name}
      )

    assert redirected_to(conn, 302) == Routes.sender_path(conn, :index, project.id)
    assert nil == Keila.Mailings.get_sender(sender.id)
  end

  @tag :sender_controller
  test "only authorized users can access sender routes", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    conn = get(conn, Routes.sender_path(conn, :edit, project.id, sender.id))
    assert html_response(conn, 200) =~ ~r{#{sender.name}\s*</h1>}

    other_user = insert!(:activated_user)

    conn =
      with_login(conn, user: other_user)
      |> get(Routes.sender_path(conn, :edit, project.id, sender.id))

    assert conn.status == 404
  end

  @tag :sender_controller
  test "sender verification verifies sender", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    {:ok, agent_pid} = Agent.start_link(fn -> nil end)
    capture_token = fn token -> Agent.update(agent_pid, fn _ -> token end) end
    Keila.Mailings.send_sender_verification_email(sender.id, &capture_token.(&1))
    token = Agent.get(agent_pid, & &1)

    conn = get(conn, Routes.sender_path(conn, :verify_from_token, token))

    assert redirected_to(conn, 302) ==
             Routes.sender_path(conn, :edit, sender.project_id, sender.id)

    verified_sender = Keila.Repo.get(Keila.Mailings.Sender, sender.id)
    assert verified_sender.verified_from_email == verified_sender.from_email

    # Can only be done once with same token
    conn = get(conn, Routes.sender_path(conn, :verify_from_token, token))
    assert html_response(conn, 404) =~ ~r{Sender verification not successful.\s*</h1>}
  end

  @tag :sender_controller
  test "sender verification shows message instead of redirect when user not logged in", %{
    conn: conn
  } do
    {_conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    {:ok, agent_pid} = Agent.start_link(fn -> nil end)
    capture_token = fn token -> Agent.update(agent_pid, fn _ -> token end) end
    Keila.Mailings.send_sender_verification_email(sender.id, &capture_token.(&1))
    token = Agent.get(agent_pid, & &1)

    conn = get(conn, Routes.sender_path(conn, :verify_from_token, token))

    assert html_response(conn, 200) =~ ~r{Sender verified!\s*</h1>}

    verified_sender = Keila.Repo.get(Keila.Mailings.Sender, sender.id)
    assert verified_sender.verified_from_email == verified_sender.from_email
  end

  @tag :sender_controller
  test "sender verification can be cancelled", %{conn: conn} do
    {conn, project} = with_login_and_project(conn)
    sender = insert!(:mailings_sender, %{project_id: project.id})

    {:ok, agent_pid} = Agent.start_link(fn -> nil end)
    capture_token = fn token -> Agent.update(agent_pid, fn _ -> token end) end
    Keila.Mailings.send_sender_verification_email(sender.id, &capture_token.(&1))
    token = Agent.get(agent_pid, & &1)

    conn = get(conn, Routes.sender_path(conn, :cancel_verification_from_token, token))
    assert html_response(conn, 404) =~ ~r{Sender verification not successful.\s*</h1>}

    unverified_sender = Keila.Repo.get(Keila.Mailings.Sender, sender.id)
    assert is_nil(unverified_sender.verified_from_email)
  end
end
