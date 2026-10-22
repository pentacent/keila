defmodule Keila.Mailings.SenderAdapters.MailgunTest do
  use ExUnit.Case, async: true
  alias Keila.Mailings.SenderAdapters.Mailgun

  @key "signing-key"
  @timestamp "1634558400"
  @token "abcdef"
  # HMAC-SHA256("signing-key", "1634558400abcdef") in hex
  @signature :crypto.mac(:hmac, :sha256, @key, @timestamp <> @token)
             |> Base.encode16(case: :lower)

  test "valid_signature?/2 accepts valid signatures" do
    signature = %{"timestamp" => @timestamp, "token" => @token, "signature" => @signature}

    assert Mailgun.valid_signature?(@key, signature)
    assert Mailgun.valid_signature?(@key, %{signature | "timestamp" => 1_634_558_400})
  end

  test "valid_signature?/2 rejects invalid signatures" do
    signature = %{"timestamp" => @timestamp, "token" => @token, "signature" => @signature}

    refute Mailgun.valid_signature?("other-key", signature)
    refute Mailgun.valid_signature?(@key, %{signature | "token" => "other"})
    refute Mailgun.valid_signature?(@key, %{signature | "signature" => "deadbeef"})
  end

  test "valid_signature?/2 rejects everything without a signing key or signature" do
    signature = %{"timestamp" => @timestamp, "token" => @token, "signature" => @signature}

    refute Mailgun.valid_signature?(nil, signature)
    refute Mailgun.valid_signature?("", signature)
    refute Mailgun.valid_signature?(@key, nil)
    refute Mailgun.valid_signature?(@key, %{})
  end
end
