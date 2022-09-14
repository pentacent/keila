defmodule Keila.Mailings.BuilderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings

  @tag :mailings_builder
  test "Builds plain-text email" do
    contact = build(:contact, id: Keila.Contacts.Contact.Id.cast(0) |> elem(1))
    sender = build(:mailings_sender)

    campaign = %Mailings.Campaign{
      project_id: Keila.Projects.Project.Id.cast(0) |> elem(1),
      subject: "My Campaign",
      sender: sender,
      text_body: """
      Hello there, {{ contact.first_name }}!
      {{ existing_assign }}
      {{ invalid_assign | default: "bar" }}
      """,
      settings: %Mailings.Campaign.Settings{
        type: :text
      }
    }

    assert email =
             %Swoosh.Email{} =
             Mailings.Builder.build(campaign, contact, %{existing_assign: "foo"})

    assert email.text_body =~ """
           Hello there, #{contact.first_name}!
           foo
           bar
           """
  end

  @tag :mailings_builder
  test "Builds Markdown email" do
    contact = build(:contact, id: Keila.Contacts.Contact.Id.cast(0) |> elem(1))
    sender = build(:mailings_sender)

    campaign = %Mailings.Campaign{
      project_id: Keila.Projects.Project.Id.cast(0) |> elem(1),
      subject: "My Campaign",
      sender: sender,
      text_body: """
      Hello there, {{ contact.first_name }}!

      This is a message with *Markdown*.
      """,
      settings: %Mailings.Campaign.Settings{
        type: :markdown
      }
    }

    assert email = %Swoosh.Email{} = Mailings.Builder.build(campaign, contact, %{})

    assert email.text_body =~ """
           Hello there, #{contact.first_name}!

           This is a message with *Markdown*.
           """

    assert email.html_body =~ ~r{Hello there, #{contact.first_name}!\s*</p>}
    assert email.html_body =~ ~r{This is a message with <em>Markdown</em>.}
  end

  @tag :mailings_builder
  test "Tracking can be enabled or disabled at the campaign-level" do
    project = insert!(:project)
    contact = insert!(:contact, project_id: project.id)
    recipient = insert!(:mailings_recipient, contact: contact, project_id: project.id)
    sender = build(:mailings_sender)

    campaign =
      insert!(:mailings_campaign,
        project_id: project.id,
        subject: "My Campaign",
        sender: sender,
        text_body: """
        [Link](https://maybe-track.example.com)
        """,
        settings: %Mailings.Campaign.Settings{
          type: :markdown
        }
      )

    email = %Swoosh.Email{} = Mailings.Builder.build(campaign, recipient, %{})
    {:ok, document} = Floki.parse_document(email.html_body)
    # When tracking is enabled, the original link is not present
    assert "https://maybe-track.example.com" not in Floki.attribute(document, "a", "href")

    campaign =
      Map.update!(campaign, :settings, fn settings -> %{settings | do_not_track: true} end)

    email = %Swoosh.Email{} = Mailings.Builder.build(campaign, recipient, %{})
    {:ok, document} = Floki.parse_document(email.html_body)
    assert "https://maybe-track.example.com" in Floki.attribute(document, "a", "href")
  end

  @tag :mailings_builder
  test "Adds X-Keila-Invalid header when there is an error" do
    contact = build(:contact, id: Keila.Contacts.Contact.Id.cast(0) |> elem(1))
    sender = build(:mailings_sender)

    campaign = %Mailings.Campaign{
      project_id: Keila.Projects.Project.Id.cast(0) |> elem(1),
      subject: "My Campaign",
      sender: sender,
      text_body: "{{ 1 | divided_by, 0 }}",
      settings: %Mailings.Campaign.Settings{
        type: :text
      }
    }

    email = Mailings.Builder.build(campaign, contact, %{})
    assert Enum.find(email.headers, fn {name, _} -> name == "X-Keila-Invalid" end)
  end

  @tag :mailings_builder
  test "Liquid in subject line is parsed" do
    contact = build(:contact, id: Keila.Contacts.Contact.Id.cast(0) |> elem(1))
    sender = build(:mailings_sender)

    campaign = %Mailings.Campaign{
      project_id: Keila.Projects.Project.Id.cast(0) |> elem(1),
      subject: "Hey {{ contact.first_name}}, are you ready for {{ campaign.data.foo }}?",
      sender: sender,
      text_body: "",
      settings: %Mailings.Campaign.Settings{
        type: :markdown
      },
      data: %{"foo" => "bar"}
    }

    assert email = %Swoosh.Email{} = Mailings.Builder.build(campaign, contact, %{})
    assert email.subject == "Hey #{contact.first_name}, are you ready for bar?"
  end
end
