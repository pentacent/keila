defmodule Keila.AuthTest.Registration do
  use ExUnit.Case, async: true
  import Keila.Factory
  import Swoosh.TestAssertions

  alias Keila.{Auth, Repo}
  alias Auth.{User, Token}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @password "BatteryHorseStaple"

  @tag :auth
  test "Create user and send activation email" do
    assert {:ok, user = %User{activated_at: nil}} =
             Auth.create_user(
               %{"email" => "foo@bar.com", "password" => @password},
               &"~~key#{&1}~~"
             )

    user_id = user.id

    receive do
      {:email, email} ->
        [_, token] = Regex.run(~r{~~key(.+)~~}, email.text_body)

        assert {:ok, %User{id: ^user_id, activated_at: %DateTime{}}} =
                 Auth.activate_user_from_token(token)
    end
  end

  @tag :auth
  test "Emails have to be unique" do
    user = insert!(:user, %{"email" => "foo@bar.com"})

    assert {:error, %Ecto.Changeset{}} =
             Auth.create_user(%{"email" => user.email, "password" => @password})
  end

  @tag :auth
  test "Find user by email" do
    user = insert!(:user)
    assert user == Auth.find_user_by_email(user.email)
    assert nil == Auth.find_user_by_email(nil)
  end

  @tag :auth
  test "Create and find user with password" do
    params = %{email: "foo@bar.com", password: @password}
    {:ok, user} = Auth.create_user(params)

    assert {:ok, ^user} = Auth.find_user_by_credentials(params)

    assert {:error, %Ecto.Changeset{}} =
             Auth.find_user_by_credentials(%{"email" => user.email, "password" => "wrong"})

    assert {:error, %Ecto.Changeset{}} = Auth.find_user_by_credentials(%{"email" => user.email})
  end

  @tag :auth
  test "Activate user" do
    assert {:ok, %User{id: id, activated_at: nil}} =
             Auth.create_user(%{"email" => "foo@bar.com", "password" => @password})

    assert {:ok, %User{activated_at: %DateTime{}}} = Auth.activate_user(id)
  end

  @tag :auth
  test "Change user email with token and send verification email" do
    user = insert!(:user)

    {:ok, token = %Auth.Token{}} =
      Auth.update_user_email(user.id, %{"email" => "new@foo.bar"}, & &1)

    assert_email_sent(Auth.Emails.build(:update_email, %{user: user, url: token.key}))

    assert {:ok, %User{email: "new@foo.bar"}} = Auth.update_user_email_from_token(token.key)
  end

  @tag :auth
  test "Change user password" do
    user = insert!(:user, %{password_hash: Argon2.hash_pwd_salt(@password)})

    Auth.update_user_password(user.id, %{
      current_password: @password,
      password: @password <> "_new"
    })
  end

  @tag :auth
  test "Create and find tokens" do
    user = insert!(:user)
    assert {:ok, %Token{} = token} = Auth.create_token(%{user_id: user.id, scope: "foo:bar"})

    assert Map.put(token, :key, nil) == Auth.find_token(token.key, token.scope)
  end

  @tag :auth
  test "Store JSON data with tokens" do
    user = insert!(:user)
    data = %{"foo" => "bar", "fizz" => "buzz"}
    params = %{user_id: user.id, scope: "foo:bar", data: data}
    {:ok, token} = Auth.create_token(params)

    assert token.data == data
  end

  @tag :auth
  test "Find and delete single-use tokens" do
    user = insert!(:user)
    {:ok, token} = Auth.create_token(%{user_id: user.id, scope: "foo:bar"})

    assert Map.put(token, :key, nil) == Auth.find_and_delete_token(token.key, token.scope)
    assert nil == Auth.find_and_delete_token(token.key, token.scope)
  end

  @tag :auth
  test "Token expiry is respected" do
    user = insert!(:user)
    past_expiry = DateTime.utc_now() |> DateTime.add(-100, :second) |> DateTime.truncate(:second)
    params = %{user_id: user.id, scope: "foo:bar", expires_at: past_expiry}

    assert {:ok, token} = Auth.create_token(params)
    assert nil == Auth.find_token(token.key, token.scope)
  end

  @tag :auth
  test "Invalid tokens fail gracefully" do
    assert nil == Auth.find_token("invalid-token", "foo:bar")
  end

  @tag :auth
  test "Send login link" do
    user = insert!(:user)

    assert :ok = Auth.send_login_link(user.id, &"~~key#{&1}~~")

    receive do
      {:email, email} ->
        [_, key] = Regex.run(~r{~~key(.+)~~}, email.text_body)
        assert %Token{} = Auth.find_token(key, "auth.login")
    end
  end

  @tag :auth
  test "Send password reset link" do
    user = insert!(:user)

    assert :ok = Auth.send_password_reset_link(user.id, &"~~key#{&1}~~")

    receive do
      {:email, email} ->
        [_, key] = Regex.run(~r{~~key(.+)~~}, email.text_body)
        assert %Token{} = Auth.find_token(key, "auth.reset")
    end
  end
end
