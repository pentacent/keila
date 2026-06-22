defmodule Keila.Mailings.MessageTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings.Message

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    {:ok, other_project} = Keila.Projects.create_project(user.id, params(:project))

    %{project: project, other_project: other_project}
  end

  describe "changeset/2 validate_assocs_project" do
    @tag :mailings_message
    test "inserts when all associations live in the same project as the message",
         %{project: project} do
      contact = insert!(:contact, project_id: project.id)
      sender = insert!(:mailings_sender, project_id: project.id)
      campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)
      form = insert!(:contacts_form, project_id: project.id)

      changeset =
        Message.changeset(%Message{}, %{
          "project_id" => project.id,
          "contact_id" => contact.id,
          "sender_id" => sender.id,
          "campaign_id" => campaign.id,
          "form_id" => form.id,
          "recipient_email" => "to@example.com"
        })

      assert {:ok, %Message{}} = Repo.insert(changeset)
    end

    @tag :mailings_message
    test "rejects contact_id belonging to a different project",
         %{project: project, other_project: other} do
      other_contact = insert!(:contact, project_id: other.id)

      changeset =
        Message.changeset(%Message{}, %{
          "project_id" => project.id,
          "contact_id" => other_contact.id,
          "recipient_email" => "to@example.com"
        })

      assert {:error, %Ecto.Changeset{} = cs} = Repo.insert(changeset)
      assert "association not found" in errors_on(cs).contact_id
    end

    @tag :mailings_message
    test "rejects campaign_id belonging to a different project",
         %{project: project, other_project: other} do
      other_sender = insert!(:mailings_sender, project_id: other.id)

      other_campaign =
        insert!(:mailings_campaign, project_id: other.id, sender_id: other_sender.id)

      changeset =
        Message.changeset(%Message{}, %{
          "project_id" => project.id,
          "campaign_id" => other_campaign.id,
          "recipient_email" => "to@example.com"
        })

      assert {:error, %Ecto.Changeset{} = cs} = Repo.insert(changeset)
      assert "association not found" in errors_on(cs).campaign_id
    end

    @tag :mailings_message
    test "rejects sender_id belonging to a different project",
         %{project: project, other_project: other} do
      other_sender = insert!(:mailings_sender, project_id: other.id)

      changeset =
        Message.changeset(%Message{}, %{
          "project_id" => project.id,
          "sender_id" => other_sender.id,
          "recipient_email" => "to@example.com"
        })

      assert {:error, %Ecto.Changeset{} = cs} = Repo.insert(changeset)
      assert "association not found" in errors_on(cs).sender_id
    end

    @tag :mailings_message
    test "rejects form_id belonging to a different project",
         %{project: project, other_project: other} do
      other_form = insert!(:contacts_form, project_id: other.id)

      changeset =
        Message.changeset(%Message{}, %{
          "project_id" => project.id,
          "form_id" => other_form.id,
          "recipient_email" => "to@example.com"
        })

      assert {:error, %Ecto.Changeset{} = cs} = Repo.insert(changeset)
      assert "association not found" in errors_on(cs).form_id
    end
  end

  describe "changeset/2 email validation" do
    @tag :mailings_message
    test "rejects malformed recipient_email" do
      changeset = Message.changeset(%{"recipient_email" => "not-an-email"})

      refute changeset.valid?
      assert "is not a valid email address" in errors_on(changeset).recipient_email
    end

    @tag :mailings_message
    test "rejects an invalid cc/bcc mailbox" do
      changeset =
        Message.changeset(%{
          "recipient_email" => "to@example.com",
          "cc" => ["Peter <peter@example.com>", "@@ nope @@"],
          "bcc" => ["lois@example.com, stewie@example.com"]
        })

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "must be a list of valid email addresses" in errors.cc
      assert "must be a list of valid email addresses" in errors.bcc
    end
  end

  describe "changeset/2 header validation" do
    @tag :mailings_message
    test "accepts a normal X-… header" do
      changeset =
        Message.changeset(build(:message), %{"headers" => %{"X-Custom-Header" => "hello"}})

      assert changeset.valid?
    end

    @tag :mailings_message
    test "accepts List-Unsubscribe despite it touching a routing concern" do
      unsubscribe =
        Message.changeset(build(:message), %{
          "headers" => %{"List-Unsubscribe" => "<https://example.com/u>"}
        })

      assert unsubscribe.valid?

      post =
        Message.changeset(build(:message), %{
          "headers" => %{"list-unsubscribe-post" => "List-Unsubscribe=One-Click"}
        })

      assert post.valid?
    end

    @tag :mailings_message
    test "rejects a CRLF in the value (header injection)" do
      changeset =
        Message.changeset(build(:message), %{
          "headers" => %{"X-Custom" => "ok\r\nBcc: evil@example.com"}
        })

      refute changeset.valid?
      assert Enum.any?(errors_on(changeset).headers, &(&1 =~ "control characters"))
    end

    @tag :mailings_message
    test "rejects other control characters in the value" do
      refute Message.changeset(build(:message), %{"headers" => %{"X-Custom" => "a\0b"}}).valid?
      refute Message.changeset(build(:message), %{"headers" => %{"X-Custom" => "a\tb"}}).valid?
    end

    @tag :mailings_message
    test "rejects a non-string key or value" do
      value = Message.changeset(build(:message), %{"headers" => %{"X-Custom" => 123}})
      assert Enum.any?(errors_on(value).headers, &(&1 =~ "non-string value"))

      name = Message.changeset(build(:message), %{"headers" => %{1 => "x"}})
      assert Enum.any?(errors_on(name).headers, &(&1 =~ "non-string name"))
    end

    @tag :mailings_message
    test "rejects a reserved header name (case-insensitive)" do
      from = Message.changeset(build(:message), %{"headers" => %{"From" => "evil@example.com"}})
      assert Enum.any?(errors_on(from).headers, &(&1 =~ "reserved name"))

      content_type =
        Message.changeset(build(:message), %{"headers" => %{"content-type" => "text/plain"}})

      assert Enum.any?(errors_on(content_type).headers, &(&1 =~ "reserved name"))
    end

    @tag :mailings_message
    test "rejects a bad-grammar header name (space or colon)" do
      for name <- ["X Custom", "X:Custom", ""] do
        changeset = Message.changeset(build(:message), %{"headers" => %{name => "v"}})
        assert Enum.any?(errors_on(changeset).headers, &(&1 =~ "invalid name"))
      end
    end

    @tag :mailings_message
    test "rejects too many headers" do
      headers = for i <- 1..31, into: %{}, do: {"X-Header-#{i}", "v"}
      changeset = Message.changeset(build(:message), %{"headers" => headers})
      refute changeset.valid?
      assert Enum.any?(errors_on(changeset).headers, &(&1 =~ "more than 30"))
    end

    @tag :mailings_message
    test "rejects a header whose line exceeds the 998-octet limit" do
      headers = %{"X-Big" => String.duplicate("a", 1_000)}
      changeset = Message.changeset(build(:message), %{"headers" => headers})
      refute changeset.valid?
      assert Enum.any?(errors_on(changeset).headers, &(&1 =~ "line length"))
    end
  end
end
