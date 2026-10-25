defmodule Keila.Mailings.SenderAdapters.CloudflareTest do
  use ExUnit.Case, async: true

  alias Keila.Mailings.Sender.Config
  alias Keila.Mailings.SenderAdapters.Cloudflare

  defp changeset(params) do
    Ecto.Changeset.change(%Config{type: "cloudflare"})
    |> Cloudflare.changeset(params)
  end

  test "is registered under its own name" do
    assert Cloudflare.name() == "cloudflare"
    assert "cloudflare" in Keila.Mailings.SenderAdapters.adapter_names()
  end

  test "requires an account ID and an API token" do
    refute changeset(%{}) |> Map.get(:valid?)
    refute changeset(%{"cloudflare_account_id" => "account-123"}).valid?
    refute changeset(%{"cloudflare_api_token" => "token"}).valid?

    assert changeset(%{
             "cloudflare_account_id" => "account-123",
             "cloudflare_api_token" => "token"
           }).valid?
  end

  test "builds the Swoosh config for the Cloudflare adapter" do
    config = %Config{
      type: "cloudflare",
      cloudflare_account_id: "account-123",
      cloudflare_api_token: "token-456"
    }

    assert Cloudflare.to_swoosh_config(%{config: config}) == [
             adapter: Keila.Mailings.SwooshAdapters.Cloudflare,
             account_id: "account-123",
             api_token: "token-456"
           ]
  end
end
