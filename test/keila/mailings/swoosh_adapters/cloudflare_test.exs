defmodule Keila.Mailings.SwooshAdapters.CloudflareTest do
  use ExUnit.Case, async: false

  alias Keila.Mailings.SwooshAdapters.Cloudflare

  # Swoosh resolves its API client from the application environment, so the test
  # swaps in a stub that records the request and replays a canned response.
  defmodule StubClient do
    @behaviour Swoosh.ApiClient

    @impl true
    def init, do: :ok

    @impl true
    def post(url, headers, body, _email) do
      Process.put(:cloudflare_request, %{url: url, headers: headers, body: body})
      Process.get(:cloudflare_response, {:ok, 200, [], success_body()})
    end

    def success_body(overrides \\ %{}) do
      Jason.encode!(
        Map.merge(
          %{
            "success" => true,
            "errors" => [],
            "result" => %{
              "message_id" => "<abc@mail.example.com>",
              "delivered" => [],
              "queued" => ["recipient@example.com"],
              "permanent_bounces" => [],
              "suppressed_recipients" => []
            }
          },
          overrides
        )
      )
    end
  end

  @config [account_id: "account-123", api_token: "token-456"]

  setup do
    previous = Application.fetch_env(:swoosh, :api_client)
    Application.put_env(:swoosh, :api_client, StubClient)

    on_exit(fn ->
      case previous do
        {:ok, client} -> Application.put_env(:swoosh, :api_client, client)
        :error -> Application.delete_env(:swoosh, :api_client)
      end
    end)

    :ok
  end

  defp email do
    Swoosh.Email.new()
    |> Swoosh.Email.from({"Keila", "news@news.example.com"})
    |> Swoosh.Email.to({"Ada", "recipient@example.com"})
    |> Swoosh.Email.subject("Hello")
    |> Swoosh.Email.text_body("Plain")
    |> Swoosh.Email.html_body("<p>Plain</p>")
  end

  defp post_request, do: Process.get(:cloudflare_request)

  defp decode(request), do: Jason.decode!(request.body)

  test "posts to the account's sending endpoint with the token as bearer auth" do
    assert {:ok, %{id: "<abc@mail.example.com>"}} = Cloudflare.deliver(email(), @config)

    request = post_request()

    assert request.url ==
             "https://api.cloudflare.com/client/v4/accounts/account-123/email/sending/send"

    assert {"Authorization", "Bearer token-456"} in request.headers
    assert {"Content-Type", "application/json"} in request.headers
  end

  test "maps the Swoosh email onto Cloudflare's structured payload" do
    Cloudflare.deliver(email(), @config)

    assert decode(post_request()) == %{
             "from" => "news@news.example.com",
             "to" => "recipient@example.com",
             "subject" => "Hello",
             "text" => "Plain",
             "html" => "<p>Plain</p>"
           }
  end

  test "sends cc and bcc as lists, and omits them when empty" do
    email =
      email()
      |> Swoosh.Email.cc({"Bob", "cc@example.com"})
      |> Swoosh.Email.bcc([{"Carol", "bcc@example.com"}])

    Cloudflare.deliver(email, @config)

    body = decode(post_request())
    assert body["cc"] == "cc@example.com"
    assert body["bcc"] == "bcc@example.com"
  end

  test "reports a permanent bounce as an invalid email so the contact is retired" do
    Process.put(
      :cloudflare_response,
      {:ok, 200, [],
       StubClient.success_body(%{
         "result" => %{
           "message_id" => "<abc@mail.example.com>",
           "delivered" => [],
           "queued" => [],
           "permanent_bounces" => ["recipient@example.com"],
           "suppressed_recipients" => []
         }
       })}
    )

    assert Cloudflare.deliver(email(), @config) == {:error, :invalid_email}
  end

  test "reports a suppressed recipient as an invalid email" do
    Process.put(
      :cloudflare_response,
      {:ok, 200, [],
       StubClient.success_body(%{
         "result" => %{
           "message_id" => "<abc@mail.example.com>",
           "delivered" => [],
           "queued" => [],
           "permanent_bounces" => [],
           "suppressed_recipients" => ["recipient@example.com"]
         }
       })}
    )

    assert Cloudflare.deliver(email(), @config) == {:error, :invalid_email}
  end

  test "returns the API errors with the status code on a failed request" do
    body =
      Jason.encode!(%{"success" => false, "errors" => [%{"code" => 1002, "message" => "nope"}]})

    Process.put(:cloudflare_response, {:ok, 403, [], body})

    assert Cloudflare.deliver(email(), @config) ==
             {:error,
              {403, %{"success" => false, "errors" => [%{"code" => 1002, "message" => "nope"}]}}}
  end

  test "passes transport errors through" do
    Process.put(:cloudflare_response, {:error, :timeout})

    assert Cloudflare.deliver(email(), @config) == {:error, :timeout}
  end
end
