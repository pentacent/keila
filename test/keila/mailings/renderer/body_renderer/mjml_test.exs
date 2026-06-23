defmodule Keila.Mailings.Renderer.BodyRenderer.MjmlTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings

  defp setup_project_and_contact do
    _root = insert!(:group)
    user = insert!(:user)
    {:ok, project} = Keila.Projects.create_project(user.id, params(:project))
    contact = insert!(:contact, project_id: project.id)
    %{project: project, contact: contact}
  end

  @template_mjml ~s(
    <mjml><mj-body>
      <keila-content name="hero">
        <mj-section><mj-column><mj-text>Default hero</mj-text></mj-column></mj-section>
      </keila-content>
      <keila-content name="footer">
        <mj-section><mj-column><mj-text>Default footer</mj-text></mj-column></mj-section>
      </keila-content>
    </mj-body></mjml>
  )

  @tag :mailings_builder
  test "campaign mjml_content fills matching template slots; unset slots keep their defaults" do
    %{project: project, contact: contact} = setup_project_and_contact()

    template =
      insert!(:template,
        project_id: project.id,
        type: :mjml,
        mjml_body: @template_mjml
      )

    sender = build(:mailings_sender)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        subject: "Hi",
        sender: sender,
        template_id: template.id,
        mjml_body: nil,
        mjml_content: %{
          "hero" =>
            "<mj-section><mj-column><mj-text>Custom hero</mj-text></mj-column></mj-section>"
        },
        settings: %Mailings.Campaign.Settings{type: :mjml}
      )
      |> Keila.Repo.preload(:template)

    email = Mailings.CampaignRenderer.render_preview(campaign, contact)

    assert email.html_body =~ "Custom hero"
    refute email.html_body =~ "Default hero"
    assert email.html_body =~ "Default footer"
    refute email.html_body =~ "keila-content"
  end

  @tag :mailings_builder
  test "campaign mjml_body overrides the template body entirely" do
    %{project: project, contact: contact} = setup_project_and_contact()

    template =
      insert!(:template,
        project_id: project.id,
        type: :mjml,
        mjml_body: @template_mjml
      )

    sender = build(:mailings_sender)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        subject: "Hi",
        sender: sender,
        template_id: template.id,
        mjml_body: "<mjml><mj-body><mj-text>Overridden</mj-text></mj-body></mjml>",
        settings: %Mailings.Campaign.Settings{type: :mjml}
      )
      |> Keila.Repo.preload(:template)

    email = Mailings.CampaignRenderer.render_preview(campaign, contact)
    assert email.html_body =~ "Overridden"
    refute email.html_body =~ "Default footer"
  end

  @tag :mailings_builder
  test "Liquid expressions in slot content are rendered after slot merging" do
    %{project: project, contact: contact} = setup_project_and_contact()

    template =
      insert!(:template,
        project_id: project.id,
        type: :mjml,
        mjml_body: ~s(
          <mjml><mj-body>
            <keila-content name="greeting">
              <mj-section><mj-column><mj-text>Hi there</mj-text></mj-column></mj-section>
            </keila-content>
          </mj-body></mjml>
        )
      )

    sender = build(:mailings_sender)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        subject: "Hello",
        sender: sender,
        template_id: template.id,
        mjml_body: nil,
        mjml_content: %{
          "greeting" =>
            ~s(<mj-section><mj-column><mj-text>Hi {{ contact.first_name }}!</mj-text></mj-column></mj-section>)
        },
        settings: %Mailings.Campaign.Settings{type: :mjml}
      )
      |> Keila.Repo.preload(:template)

    email = Mailings.CampaignRenderer.render_preview(campaign, contact)

    assert email.html_body =~ "Hi #{contact.first_name}!"
    refute email.html_body =~ "{{ contact.first_name }}"
  end

  @tag :mailings_builder
  test "keila-code wrapper tags are stripped and the Liquid inside is rendered" do
    %{project: project, contact: contact} = setup_project_and_contact()

    sender = build(:mailings_sender)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        subject: "Hi",
        sender: sender,
        mjml_body:
          ~s(<mjml><mj-body><mj-section><mj-column><mj-text><keila-code>Hi {{ contact.first_name }}</keila-code></mj-text></mj-column></mj-section></mj-body></mjml>),
        settings: %Mailings.Campaign.Settings{type: :mjml}
      )
      |> Keila.Repo.preload(:template)

    email = Mailings.CampaignRenderer.render_preview(campaign, contact)

    assert email.html_body =~ "Hi #{contact.first_name}"
    refute email.html_body =~ "keila-code"
  end
end
