require Keila

Keila.if_cloud do
  defmodule KeilaCloudSenderCreateLiveTest do
    use KeilaWeb.ConnCase
    import Phoenix.LiveViewTest
    alias Keila.Mailings
    alias KeilaCloud.Mailings.SendWithKeila

    @email_with_configured_domain "test@test.keilamails.com"
    @email_with_new_domain "test@test-not-set-up.keilamails.com"
    @email_with_shared_domain "keila+test@mailbox.org"

    @tag :cloud_sender_create_live
    test "creates sender with domain that's already set up", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      [user] = Keila.Auth.list_group_users(project.group_id)

      {:ok, live, html} = live(conn, Routes.sender_path(conn, :new, project.id))

      # Select "Send with Keila" option (use_swk: true)
      do_render_submit(live, sender: %{use_swk: "true"})

      # Sender name input defaults to project name
      assert live
             |> element("input[name='sender[name]'][value='#{project.name}']")
             |> has_element?()

      do_render_submit(live)

      # Sender email defaults to user email
      assert live
             |> element("input[name='sender[email]'][value='#{user.email}']")
             |> has_element?()

      assert {:ok, conn} =
               live
               |> do_render_submit(sender: %{email: @email_with_configured_domain})
               |> follow_redirect(conn)

      {:ok, live, html} = live(conn, conn.request_path)

      # Email verification message is shown
      assert live
             |> element("h3", "Waiting for email verification ...")
             |> has_element?()

      # Sender was created
      assert sender = Keila.Repo.one(Keila.Mailings.Sender)

      # Sender is not ready to use
      assert_raise(FunctionClauseError, fn ->
        SendWithKeila.to_swoosh_config(sender)
      end)

      # Verification email was sent
      {:email, %{text_body: text_body}} = assert_email_sent()
      refute_email_sent()
      [_, verification_code] = Regex.run(~r{verify-sender/([^\s]+)}, text_body)

      # Submit verification code
      assert conn
             |> get(Routes.sender_path(conn, :verify_from_token, verification_code))
             |> html_response(302)

      # Liveview shows verification success message
      assert live
             |> element("div", "Email verified")
             |> has_element?()

      # Sender is now ready to use
      sender = Keila.Repo.reload!(sender)
      assert SendWithKeila.to_swoosh_config(sender)

      # Since the domain is not yet verified, the from email is using a Keila domain
      fallback_address = SendWithKeila.fallback_from_email(sender)
      {_, ^fallback_address} = SendWithKeila.from(sender)
      {_, @email_with_configured_domain} = SendWithKeila.reply_to(sender)

      # Liveview shows verification success message
      Oban.drain_queue(queue: :domain_verification)

      assert live
             |> element("div", "Domain verified")
             |> has_element?()

      # Liveview shows setup in progress message
      assert live
             |> element("h3", "Finalizing your sender ...")
             |> has_element?()

      # Since MX2 won't actually be set up in the test environment, we just pretend it did.
      sender = mock_setup_mx2(sender)
      assert {_, @email_with_configured_domain} = SendWithKeila.from(sender)
      assert nil == SendWithKeila.reply_to(sender)

      # Liveview shows setup in progress message
      refute live
             |> element("h3", "Finalizing your sender ...")
             |> has_element?()
    end

    @tag :cloud_sender_create_live
    test "creates sender with an unverified custom domain", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      [user] = Keila.Auth.list_group_users(project.group_id)

      {:ok, live, html} = live(conn, Routes.sender_path(conn, :new, project.id))

      # Select "Send with Keila" option (use_swk: true)
      do_render_submit(live, sender: %{use_swk: "true"})
      # Submit default name
      do_render_submit(live)

      assert {:ok, conn} =
               live
               |> do_render_submit(sender: %{email: @email_with_new_domain})
               |> follow_redirect(conn)

      {:ok, live, html} = live(conn, conn.request_path)

      # Email verification message is shown
      assert live
             |> element("h3", "Waiting for email verification ...")
             |> has_element?()

      # Sender was created
      assert sender = Keila.Repo.one(Keila.Mailings.Sender)

      # Sender is not ready to use
      assert_raise(FunctionClauseError, fn ->
        SendWithKeila.to_swoosh_config(sender)
      end)

      # Verification email was sent
      {:email, %{text_body: text_body}} = assert_email_sent()
      refute_email_sent()
      [_, verification_code] = Regex.run(~r{verify-sender/([^\s]+)}, text_body)

      # Submit verification code
      assert conn
             |> get(Routes.sender_path(conn, :verify_from_token, verification_code))
             |> html_response(302)

      # Liveview shows verification success message
      assert live
             |> element("div", "Email verified")
             |> has_element?()

      # Sender is now ready to use
      sender = Keila.Repo.reload!(sender)
      assert SendWithKeila.to_swoosh_config(sender)

      # Since the domain is not yet verified, the from email is using a Keila domain
      fallback_address = SendWithKeila.fallback_from_email(sender)
      {_, ^fallback_address} = SendWithKeila.from(sender)
      {_, @email_with_new_domain} = SendWithKeila.reply_to(sender)

      # The domain verification queue sets swk_domain_is_known_shared_domain.
      Oban.drain_queue(queue: :domain_verification)

      sender = Keila.Repo.reload!(sender)
      refute sender.config.swk_domain_is_known_shared_domain

      # LiveView shows information message regarding shared domain
      assert render(live) =~ "Waiting for domain verification ..."
    end

    @tag :cloud_sender_create_live
    test "creates sender with a known shared domain", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      [user] = Keila.Auth.list_group_users(project.group_id)

      {:ok, live, html} = live(conn, Routes.sender_path(conn, :new, project.id))

      # Select "Send with Keila" option (use_swk: true)
      do_render_submit(live, sender: %{use_swk: "true"})
      # Submit default name
      do_render_submit(live)

      assert {:ok, conn} =
               live
               |> do_render_submit(sender: %{email: @email_with_shared_domain})
               |> follow_redirect(conn)

      {:ok, live, html} = live(conn, conn.request_path)

      # Email verification message is shown
      assert live
             |> element("h3", "Waiting for email verification ...")
             |> has_element?()

      # Sender was created
      assert sender = Keila.Repo.one(Keila.Mailings.Sender)

      # Sender is not ready to use
      assert_raise(FunctionClauseError, fn ->
        SendWithKeila.to_swoosh_config(sender)
      end)

      # Verification email was sent
      {:email, %{text_body: text_body}} = assert_email_sent()
      refute_email_sent()
      [_, verification_code] = Regex.run(~r{verify-sender/([^\s]+)}, text_body)

      # Submit verification code
      assert conn
             |> get(Routes.sender_path(conn, :verify_from_token, verification_code))
             |> html_response(302)

      # Liveview shows verification success message
      assert live
             |> element("div", "Email verified")
             |> has_element?()

      # Sender is now ready to use
      sender = Keila.Repo.reload!(sender)
      assert SendWithKeila.to_swoosh_config(sender)

      # Since the domain is not yet verified, the from email is using a Keila domain
      fallback_address = SendWithKeila.fallback_from_email(sender)
      {_, ^fallback_address} = SendWithKeila.from(sender)
      {_, @email_with_shared_domain} = SendWithKeila.reply_to(sender)

      # The domain verification queue sets swk_domain_is_known_shared_domain.
      Oban.drain_queue(queue: :domain_verification)

      sender = Keila.Repo.reload!(sender)
      assert sender.config.swk_domain_is_known_shared_domain

      # LiveView shows information message regarding shared domain
      assert render(live) =~ "You’re using a shared domain."
    end

    test "creates SMTP sender", %{conn: conn} do
      {conn, project} = with_login_and_project(conn)
      [user] = Keila.Auth.list_group_users(project.group_id)

      {:ok, live, html} = live(conn, Routes.sender_path(conn, :new, project.id))

      # Select "Send with Keila" option (use_swk: true)
      do_render_submit(live, sender: %{use_swk: "false"})

      # Accept default name
      do_render_submit(live)

      # Accept default from email
      do_render_submit(live)

      # Select SMTP
      do_render_submit(live, sender: %{"adapter_type" => "smtp"})

      # Set SMTP credentials
      assert {:ok, conn} =
               do_render_submit(live,
                 sender: %{
                   adapter_config: %{
                     smtp_relay: "example.com",
                     smtp_username: "user",
                     smtp_password: "password",
                     smtp_port: "587"
                   }
                 }
               )
               |> follow_redirect(conn)

      # We're not yet sending verification emails to non-SWK senders
      refute_email_sent()
    end

    defp do_render_submit(live, form_data \\ []) do
      live
      |> form("#form", form_data)
      |> render_submit()
    end

    defp mock_setup_mx2(sender) do
      {:ok, sender} =
        Mailings.update_sender(
          sender.id,
          %{config: %{id: sender.config.id, swk_mx2_set_up_at: DateTime.utc_now(:second)}},
          config_cast_opts: [with: &SendWithKeila.private_changeset/2]
        )

      sender
    end
  end
end
