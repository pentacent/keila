defmodule KeilaWeb.SenderControllerTest do
  use KeilaWeb.ConnCase, async: false
  require Keila
  import Phoenix.LiveViewTest

  setup :set_swoosh_global

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

  Keila.unless_cloud do
    @tag :sender_controller
    test "creates sender with test adapter and completes email verification", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)

      {:ok, lv, _html} = live(conn, Routes.sender_path(conn, :new, project.id))

      # Submit the form to create a new sender
      sender_params = %{
        "name" => "Test Sender",
        "from_name" => "Test Newsletter",
        "from_email" => "test@example.com",
        "config" => %{
          "type" => "test"
        }
      }

      lv
      |> form("#form", sender: sender_params)
      |> render_submit()

      # The test adapter requires verification of the from email address.
      assert render(lv) =~ "Waiting for email verification ..."

      # Verify sender was created with correct attributes
      [sender] = Keila.Mailings.get_project_senders(project.id)
      assert sender.name == sender_params["name"]
      assert sender.from_name == sender_params["from_name"]
      assert sender.from_email == sender_params["from_email"]
      assert sender.config.type == "test"
      assert is_nil(sender.verified_from_email)

      # Verification email should have been sent
      {:email, %{text_body: text_body}} = assert_email_sent()
      refute_email_sent()
      [_, token] = Regex.run(~r{verify-sender/([^\s]+)}, text_body)

      # Submitting the verification redirects to edit page
      conn = get(conn, Routes.sender_path(conn, :verify_from_token, token))
      assert redirected_to(conn, 302) == Routes.sender_path(conn, :edit, project.id, sender.id)

      # The LiveView updates automatically and shows the verification success message
      assert render(lv) =~ "Email verified"
      refute render(lv) =~ "Waiting for email verification ..."

      # Sender from email is now verified
      sender = Keila.Repo.reload(sender)
      assert sender.verified_from_email == sender_params["from_email"]
    end
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
    sender = insert!(:mailings_sender, %{project_id: project.id, config: %{type: "test"}})
    {:ok, lv, _html} = live(conn, Routes.sender_path(conn, :edit, project.id, sender.id))

    params = %{"name" => "Updated Name"}

    lv
    |> form("#form", sender: params)
    |> render_submit()

    assert_redirect(lv, Routes.sender_path(conn, :index, project.id))

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
