defmodule Keila.Mailings.CampaignRendererTest do
  use Keila.DataCase, async: false
  alias Keila.Mailings.CampaignRenderer
  alias Keila.Mailings.Renderer.Input

  setup do
    _root = insert!(:group)
    :ok
  end

  test "maps campaign fields, type, and adds campaign assign" do
    campaign = %Keila.Mailings.Campaign{
      id: "mc_1",
      project_id: "p_1",
      subject: "S",
      mjml_body: "<mjml></mjml>",
      data: %{"k" => "v"},
      settings: %Keila.Mailings.Campaign.Settings{type: :mjml},
      template: nil,
      sender: nil
    }

    contact = %Keila.Contacts.Contact{id: "c_1", email: "a@b.c", data: %{}}

    assert %Input{} = r = CampaignRenderer.to_input(campaign, contact)
    assert r.type == :mjml
    assert r.mjml_body == "<mjml></mjml>"
    assert r.recipient_email == "a@b.c"
    assert r.assigns["campaign"][:data] == %{"k" => "v"}
  end

  test "render/2 returns rendered content for a campaign message" do
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    contact = insert!(:contact, project_id: project.id)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        settings: %{type: :text},
        text_body: "hi"
      )

    message =
      insert!(:message, campaign_id: campaign.id, project_id: project.id, contact: contact)

    output = CampaignRenderer.render(campaign, message)
    assert output.text_body =~ "hi"
  end

  test "render/2 rewrites external links and injects a tracking pixel" do
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    contact = insert!(:contact, project_id: project.id)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        settings: %{type: :html},
        html_body: ~s(<html><body><a href="https://example.com/x">link</a></body></html>)
      )

    message =
      insert!(:message, campaign_id: campaign.id, project_id: project.id, contact: contact)

    output = CampaignRenderer.render(campaign, message)
    refute output.html_body =~ ~s(href="https://example.com/x")
    assert output.html_body =~ "<img"
  end

  test "render/2 skips tracking when do_not_track is set" do
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    contact = insert!(:contact, project_id: project.id)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        settings: %{type: :html, do_not_track: true},
        html_body: ~s(<html><body><a href="https://example.com/x">link</a></body></html>)
      )

    message =
      insert!(:message, campaign_id: campaign.id, project_id: project.id, contact: contact)

    output = CampaignRenderer.render(campaign, message)
    assert output.html_body =~ ~s(href="https://example.com/x")
  end

  test "render_preview/2 interpolates Liquid in the subject, including the campaign assign" do
    campaign = %Keila.Mailings.Campaign{
      project_id: "p_1",
      subject: "Hey {{ contact.first_name }}, are you ready for {{ campaign.data.foo }}?",
      text_body: "",
      settings: %Keila.Mailings.Campaign.Settings{type: :markdown},
      data: %{"foo" => "bar"},
      template: nil,
      sender: nil
    }

    contact = %Keila.Contacts.Contact{
      id: "c_1",
      first_name: "Jane",
      email: "jane@example.com",
      data: %{}
    }

    output = CampaignRenderer.render_preview(campaign, contact)
    assert output.subject == "Hey Jane, are you ready for bar?"
  end
end
