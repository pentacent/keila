defmodule Keila.Mailings.SharedSenderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.SharedSender

  @tag :mailings
  test "Get SharedSenders" do
    shared_sender = insert!(:mailings_shared_sender)
    assert shared_sender == Mailings.get_shared_sender(shared_sender.id)
  end

  @tag :mailings
  test "Create Shared Sender" do
    {:ok, %SharedSender{}} =
      Mailings.create_shared_sender(%{
        "name" => "Shared Sender",
        "config" => %{
          "ses_region" => "eu-west-1",
          "ses_access_key" => "access_key",
          "ses_secret" => "secret"
        }
      })
  end

  @tag :mailings
  test "Update SharedSenders" do
    shared_sender = insert!(:mailings_shared_sender)

    assert {:ok, %{name: "Updated name"}} =
             Mailings.update_shared_sender(shared_sender.id, %{name: "Updated name"})
  end

  @tag :mailings
  test "List SharedSenders" do
    shared_sender = insert!(:mailings_shared_sender)
    assert [shared_sender] == Mailings.get_shared_senders()
  end

  @tag :mailings
  test "Delete SharedSenders" do
    shared_sender = insert!(:mailings_shared_sender)
    assert :ok == Mailings.delete_shared_sender(shared_sender.id)
    # Is idempotent
    assert :ok == Mailings.delete_shared_sender(shared_sender.id)
  end
end
