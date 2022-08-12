defmodule Keila.Mailings.SendersSESTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings

  @aws_key "SimpleNotificationService-7ff5318490ec183fbaddaa2a969abfda.pem"

  setup do
    # Add AWS key to cache because otherwise test data might go stale when
    # AWS cycles keys
    Path.join(:code.priv_dir(:keila), "vendor/aws/#{@aws_key}")
    |> File.read!()
    |> Keila.Mailings.SenderAdapters.SES.extract_key()
    |> then(fn key ->
      Keila.Mailings.SenderAdapters.SES.put_cached_key(
        "https://sns.eu-central-1.amazonaws.com/#{@aws_key}",
        key
      )
    end)

    :ok
  end

  @tag :mailings_ses
  test "validate signature from SES/SNS notification" do
    notification =
      File.read!("test/keila/mailings/ses/bounce.signed.json")
      |> Jason.decode!()

    assert true == Mailings.SenderAdapters.SES.valid_signature?(notification)
  end
end
