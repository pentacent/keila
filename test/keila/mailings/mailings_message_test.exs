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
end
