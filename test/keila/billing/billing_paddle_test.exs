defmodule Keila.Billing.PaddleTest do
  use Keila.DataCase, async: false
  alias Keila.Billing.Paddle

  setup do
    signature_verification_enabled_before? =
      Application.get_env(:keila, Keila.Billing, [])
      |> Keyword.get(:paddle_signature_verification_enabled, true)

    set_signature_verification_enabled(true)
    on_exit(fn -> set_signature_verification_enabled(signature_verification_enabled_before?) end)
  end

  describe "paddle signature verification" do
    @tag :billing
    test "validates correctly signed params" do
      assert true ==
               File.read!("test/keila/billing/subscription_created.signed.json")
               |> Jason.decode!()
               |> Paddle.valid_signature?()
    end

    @tag :billing
    test "rejects incorrectly signed params" do
      assert false ==
               File.read!("test/keila/billing/subscription_created.unsigned.json")
               |> Jason.decode!()
               |> Paddle.valid_signature?()
    end

    @tag :billing
    test "rejects invalid params" do
      assert false == Paddle.valid_signature?(%{"foo" => "bar"})
    end
  end

  defp set_signature_verification_enabled(enable?) do
    config =
      Application.get_env(:keila, Keila.Billing, [])
      |> Keyword.put(:paddle_signature_verification_enabled, enable?)

    Application.put_env(:keila, Keila.Billing, config)
  end
end
