defmodule Keila.MailingsPublicCampaignTest do
  use Keila.DataCase, async: true

  alias Keila.{Projects, Mailings}

  setup do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Projects.create_project(user.id, params(:project))

    %{project: project}
  end

  @tag :mailings_campaign
  test "enable_public_link!/2 updates public_link_enabled field", %{project: project} do
    campaign = insert!(:mailings_campaign, project_id: project.id) |> Repo.reload!()

    assert campaign.public_link_enabled == false
    assert %{public_link_enabled: true} = Mailings.enable_public_link!(campaign.id)
    assert %{public_link_enabled: false} = Mailings.enable_public_link!(campaign.id, false)
  end
end
