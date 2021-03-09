defmodule Keila.MailingsCampaignTest do
  use Keila.DataCase, async: true
  use Oban.Testing, repo: Keila.Repo

  alias Keila.{Projects, Mailings, Contacts}

  @delivery_n 50

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :mailings_campaign
  test "create campaign", %{project: project} do
    sender = insert!(:mailings_sender)
    params = params(:mailings_campaign, sender_id: sender.id)
    assert {:ok, %Mailings.Campaign{}} = Mailings.create_campaign(project.id, params)
  end

  @tag :mailings_campaign
  test "clone campaign", %{project: project} do
    sender = insert!(:mailings_sender, project_id: project.id)
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    {:ok, cloned_campaign} =
      Mailings.clone_campaign(campaign.id, %{"subject" => "My new subject"})

    assert cloned_campaign.subject == "My new subject"
  end

  @tag :mailings_campaign
  test "list campaigns", %{project: project} do
    campaigns = insert_n!(:mailings_campaign, 5, fn _ -> %{project_id: project.id} end)
    retrieved_campaigns = Mailings.get_project_campaigns(project.id)

    assert Enum.count(campaigns) == Enum.count(retrieved_campaigns)

    for campaign <- retrieved_campaigns do
      assert campaign in campaigns
    end
  end

  @tag :mailings_campaign
  test "delete campaign", %{project: project} do
    campaign = insert!(:mailings_campaign, project_id: project.id)
    assert :ok = Mailings.delete_campaign(campaign.id)
    assert nil == Mailings.get_campaign(campaign.id)
  end

  @tag :mailings_campaign
  test "delete project campaigns", %{project: project} do
    campaigns = insert_n!(:mailings_campaign, 5, fn _ -> %{project_id: project.id} end)
    other_campaign = insert!(:mailings_campaign)

    assert :ok =
             Mailings.delete_project_campaigns(
               project.id,
               Enum.map(campaigns, & &1.id) ++ [other_campaign.id]
             )

    assert [] == Mailings.get_project_campaigns(project.id)
    assert other_campaign == Mailings.get_campaign(other_campaign.id)
  end

  @tag :mailings_campaign
  test "deliver campaign", %{project: project} do
    n = @delivery_n

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    build_n(:contact, n, fn _ -> %{project_id: project.id} end)
    |> Enum.map(&Map.take(&1, [:name, :project_id, :email, :first_name, :last_name]))
    |> Enum.map(&Map.merge(&1, %{updated_at: now, inserted_at: now}))
    |> Enum.chunk_every(10_000)
    |> Enum.each(fn params -> Repo.insert_all(Contacts.Contact, params) |> elem(1) end)

    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    assert :ok = Mailings.deliver_campaign(campaign.id)

    assert %{success: ^n, failure: 0} = Oban.drain_queue(queue: :mailer)

    for _ <- 1..n do
      assert_email_sent()
    end

    refute_email_sent()
  end

  @tag :mailings_campaign
  test "campaign with no recipients is not delivered", %{project: project} do
    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})
    campaign = insert!(:mailings_campaign, project_id: project.id, sender_id: sender.id)

    assert {:error, :no_recipients} = Mailings.deliver_campaign(campaign.id)
    assert %{sent_at: nil} = Mailings.get_campaign(campaign.id)
  end

  @tag :mailings_campaign
  test "campaign that has been delivered is not delivered again", %{project: project} do
    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})
    sent_at = DateTime.utc_now() |> DateTime.truncate(:second)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        sender_id: sender.id,
        sent_at: sent_at
      )

    assert {:error, :already_sent} = Mailings.deliver_campaign(campaign.id)
    assert %{sent_at: ^sent_at} = Mailings.get_campaign(campaign.id)
  end

  @tag :mailings_campaign
  test "deliver scheduled campaign", %{project: project} do
    n = @delivery_n

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    build_n(:contact, n, fn _ -> %{project_id: project.id} end)
    |> Enum.map(&Map.take(&1, [:name, :project_id, :email, :first_name, :last_name]))
    |> Enum.map(&Map.merge(&1, %{updated_at: now, inserted_at: now}))
    |> Enum.chunk_every(10_000)
    |> Enum.each(fn params -> Repo.insert_all(Contacts.Contact, params) |> elem(1) end)

    sender = insert!(:mailings_sender, config: %Mailings.Sender.Config{type: "test"})

    [campaign_too_late, campaign_in_time, campaign_later] =
      insert_n!(:mailings_campaign, 3, fn _ -> %{project_id: project.id, sender_id: sender.id} end)

    assert {:error, _changeset} =
             Mailings.schedule_campaign(campaign_too_late.id, %{
               # scheduling before configured theshold
               "scheduled_for" => DateTime.utc_now() |> DateTime.add(-3600, :second)
             })

    assert {:ok, _struct} =
             Mailings.schedule_campaign(campaign_in_time.id, %{
               # deliver in 5:30 minutes
               "scheduled_for" => DateTime.utc_now()
             })

    assert {:ok, _struct} =
             Mailings.schedule_campaign(campaign_later.id, %{
               # deliver in 1 hour
               "scheduled_for" => DateTime.utc_now() |> DateTime.add(3600, :second)
             })

    assert :ok = perform_job(Mailings.DeliverScheduledCampaignsWorker, %{})
    assert %{success: ^n, failure: 0} = Oban.drain_queue(queue: :mailer)

    assert %Mailings.Campaign{sent_at: sent_at} = Mailings.get_campaign(campaign_in_time.id)
    assert sent_at

    assert %Mailings.Campaign{sent_at: nil} = Mailings.get_campaign(campaign_later.id)

    for _ <- 1..n do
      assert_email_sent()
    end

    refute_email_sent()
  end

  @tag :mailings_campaign
  test "campaigns cannot be rescheduled when too close to delivery threshold", %{project: project} do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    one_hour_ago = now |> DateTime.add(-3600, :second)
    in_one_hour = now |> DateTime.add(3600, :second)

    campaign = insert!(:mailings_campaign, project_id: project.id, scheduled_for: one_hour_ago)

    assert {:error, _changeset} =
             Mailings.schedule_campaign(campaign.id, %{"scheduled_for" => in_one_hour})
  end
end
