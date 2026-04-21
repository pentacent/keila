defmodule Keila.Mailings.CampaignRendererWorkerTest do
  use Keila.DataCase, async: true
  use Oban.Testing, repo: Keila.Repo

  alias Keila.{Projects, Mailings}
  alias Keila.Mailings.Message

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :mailings_worker
  test "renders campaign messages and updates status to :ready", %{
    project: project
  } do
    contact = insert!(:contact, project_id: project.id)
    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        sender_id: sender.id,
        text_body: "Hello {{ contact.first_name }}",
        settings: %Mailings.Campaign.Settings{type: :text}
      )

    assert :ok = Mailings.deliver_campaign(campaign.id)

    # Rendering job completes successfully
    assert %{success: 1} = Oban.drain_queue(queue: :campaign_renderer)

    # Message is marked as ready
    message = get_message_for_contact(campaign.id, contact.id)
    assert message.status == :ready
  end

  @tag :mailings_worker
  test "sets failed_at but does not change contact status for template rendering error", %{
    project: project
  } do
    contact = insert!(:contact, project_id: project.id)
    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        sender_id: sender.id,
        text_body: "Hello {{ 1 | divided_by: 0 }}",
        settings: %Mailings.Campaign.Settings{type: :text}
      )

    assert :ok = Mailings.deliver_campaign(campaign.id)

    # Rendering job completes successfully
    assert %{success: 1} = Oban.drain_queue(queue: :campaign_renderer)

    # Message is marked as failed
    message = get_message_for_contact(campaign.id, contact.id)
    assert message.failed_at
    assert message.status == :failed

    # Verify contact status did not change
    contact = Repo.reload(contact)
    assert contact.status == :active
  end

  defp get_message_for_contact(campaign_id, contact_id) do
    import Ecto.Query

    from(r in Message,
      where: r.campaign_id == ^campaign_id and r.contact_id == ^contact_id
    )
    |> Keila.Repo.one()
  end
end
