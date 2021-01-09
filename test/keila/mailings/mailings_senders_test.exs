defmodule Keila.Mailings.SenderTest do
  use ExUnit.Case, async: true
  import Keila.Factory

  alias Keila.{Mailings, Repo}
  alias Mailings.Sender

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  @tag :mailings
  test "Create senders" do
    group = insert!(:group)
    project = insert!(:project, group: group)

    {:ok, %Sender{}} =
      Mailings.create_sender(project.id, %{
        "name" => "Sender",
        "from_email" => "foo@bar.com",
        "config" => %{
          "type" => "smtp",
          "smtp_username" => "foo",
          "smtp_password" => "foo",
          "smtp_relay" => "example.com"
        }
      })
  end

  test "Delete senders" do
  end

  test "Update senders" do
  end
end
