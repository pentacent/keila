defmodule Keila.Auth.SystemMailerWorkerTest do
  use Keila.DataCase, async: true
  use Oban.Testing, repo: Keila.Repo

  alias Keila.Auth
  alias Keila.Auth.Emails
  alias Keila.Auth.SystemMailerWorker

  @tag :auth
  test "send_later/2 enqueues sending job with current locale, SystemMailerWorker generates token in-memory when sending" do
    user = insert!(:user, email: "peter@example.com")

    Gettext.with_locale("de", fn ->
      assert %Oban.Job{} =
               Emails.send_later(:password_reset_link, %{
                 user: user,
                 url_fn: &url_fn/1,
                 token_params: %{scope: "auth.reset", user_id: user.id}
               })
    end)

    assert_enqueued(
      worker: SystemMailerWorker,
      args: %{
        "email" => "password_reset_link",
        "locale" => "de",
        "params" => %{
          "user_id" => user.id,
          "url" => "https://example.com/t/__KEILA_TOKEN__"
        }
      }
    )

    # Token is not persisted in SystemMailerWorker args
    assert 0 == Keila.Repo.aggregate(Auth.Token, :count)

    assert %{success: 1} = Oban.drain_queue(queue: :system_mailer)

    {:email, email} = assert_email_sent()
    assert email.subject == "Dein Account-Zurücksetzungs-Link"
    assert {"Keila", "keila@localhost"} == email.from
    assert [{"", "peter@example.com"}] == email.to
    [_, key] = Regex.run(~r{https://example\.com/t/([^\s]+)}, email.text_body)
    refute key == "__KEILA_TOKEN__"
    assert %Auth.Token{} = Auth.find_token(key, "auth.reset")
  end

  @tag :auth
  test "cancels when the user no longer exists" do
    user = insert!(:user)
    user_id = user.id
    :ok = Auth.delete_user(user.id)

    Emails.send_later(:login_link, %{
      user: user,
      url_fn: &url_fn/1,
      token_params: %{scope: "auth.login", user_id: user_id}
    })

    assert %{cancelled: 1} = Oban.drain_queue(queue: :system_mailer)
    assert_no_email_sent()
    assert 0 == Keila.Repo.aggregate(Auth.Token, :count)
  end

  defp url_fn(token), do: "https://example.com/t/#{token}"
end
