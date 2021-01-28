defmodule Keila.Mailings.BuilderTest do
  use Keila.DataCase, async: true
  alias Keila.Mailings
  alias Mailings.Sender

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

    assert email.text_body == """
           Hello there, #{contact.first_name}!
           foo
           bar
           """
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
end
