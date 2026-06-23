defmodule Keila.Mailings.Renderer.RenderTest do
  use ExUnit.Case, async: true
  alias Keila.Mailings.Renderer
  alias Keila.Mailings.Renderer.Input
  alias Keila.Contacts.Contact

  defp contact, do: %Contact{id: "c_1", first_name: "Jane", email: "jane@example.com", data: %{}}

  test "renders the subject and text body, interpolating contact + unsubscribe_link" do
    r = %Input{
      type: :text,
      subject: "Hi {{ contact.first_name }}",
      text_body: "Hi {{ contact.first_name }} {{ unsubscribe_link }}",
      contact: contact(),
      assigns: %{"unsubscribe_link" => "https://example.com/u/1"}
    }

    output = Renderer.render(r)
    assert output.valid?
    assert output.subject == "Hi Jane"
    assert output.text_body =~ "Hi Jane"
    assert output.text_body =~ "https://example.com/u/1"
    assert is_nil(output.html_body)
  end

  test "renders mjml into html and a derived text part" do
    r = %Input{
      type: :mjml,
      subject: "s",
      mjml_body: "<mjml><mj-body><mj-text>Hi {{ contact.first_name }}</mj-text></mj-body></mjml>",
      contact: contact()
    }

    output = Renderer.render(r)
    assert output.valid?
    assert output.html_body =~ "Hi Jane"
    assert output.text_body =~ "Hi Jane"
  end

  test "renders markdown into a text part and an html part" do
    r = %Input{
      type: :markdown,
      subject: "s",
      text_body: "Hello there, {{ contact.first_name }}!\n\nThis is *Markdown*.\n",
      contact: contact()
    }

    output = Renderer.render(r)
    assert output.valid?
    assert output.text_body =~ "Hello there, Jane!"
    assert output.html_body =~ ~r{Hello there, Jane!\s*</p>}
    assert output.text_body =~ "*Markdown*"
    assert output.html_body =~ "<em>Markdown</em>"
  end

  test "render_preview uses the placeholder unsubscribe link" do
    r = %Input{
      type: :text,
      subject: "s",
      text_body: "hi {{ unsubscribe_link }}",
      contact: contact()
    }

    output = Renderer.render_preview(r)
    assert output.valid?
    assert output.text_body =~ "#unsubscribe-preview-link"
  end

  test "a Liquid error marks the output invalid and collects the error" do
    r = %Input{
      type: :mjml,
      subject: "s",
      mjml_body: "<mjml><mj-body><mj-text>{{ broken </mj-text></mj-body></mjml>",
      contact: contact()
    }

    output = Renderer.render(r)
    refute output.valid?
    assert [_ | _] = output.errors
  end

  test "exposes contact.display_name built from the contact" do
    r = %Input{
      type: :text,
      subject: "s",
      text_body: "Hello {{ contact.display_name }}",
      contact: contact()
    }

    output = Renderer.render(r)
    assert output.text_body =~ "Hello Jane"
  end

  test "contact.display_name falls back to recipient_name when there is no contact" do
    r = %Input{
      type: :text,
      subject: "s",
      text_body: "Hello {{ contact.display_name }}",
      recipient_email: "jane@example.com",
      recipient_name: "Jane Doe"
    }

    output = Renderer.render(r)
    assert output.text_body =~ "Hello Jane Doe"
  end
end
