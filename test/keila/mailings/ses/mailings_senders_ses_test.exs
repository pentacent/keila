defmodule Keila.Mailings.SendersSESTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings

  @tag :mailings_ses
  test "validate signature from SES/SNS notification" do
    notification =
      File.read!("test/keila/mailings/ses/bounce.signed.json")
      |> Jason.decode!()

    assert true == Mailings.SenderAdapters.SES.valid_signature?(notification)
  end
end
