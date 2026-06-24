defmodule Keila.Templates.ContentSlotsTest do
  use ExUnit.Case, async: true
  alias Keila.Templates
  alias Keila.Templates.Slot

  describe "get_content_slots/2 with mjml" do
    test "extracts only direct children of mj-body" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Direct</keila-content>
        <mj-section><mj-column>
          <keila-content name="nested">ignored</keila-content>
        </mj-column></mj-section>
      </mj-body></mjml>
      """

      assert [%Slot{name: "hero"}] = Templates.get_content_slots(mjml, mode: :mjml)
    end

    test "captures the default content of a slot" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="hero">Direct content</keila-content></mj-body></mjml>)

      assert [%Slot{name: "hero", default_content: "Direct content\n"}] =
               Templates.get_content_slots(mjml, mode: :mjml)
    end

    test "preserves markup and Liquid in default content" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="hero"><mj-text>Hi {{ name }}</mj-text></keila-content></mj-body></mjml>)

      assert [%Slot{name: "hero", default_content: "<mj-text>\n  Hi {{ name }}\n</mj-text>\n"}] =
               Templates.get_content_slots(mjml, mode: :mjml)
    end

    test "returns empty list for nil input" do
      assert Templates.get_content_slots(nil, mode: :mjml) == []
    end

    test "skips slots without a name attribute" do
      mjml = """
      <mjml><mj-body>
        <keila-content>no name</keila-content>
        <keila-content name="">empty name</keila-content>
        <keila-content name="ok">y</keila-content>
      </mj-body></mjml>
      """

      assert [%Slot{name: "ok"}] = Templates.get_content_slots(mjml, mode: :mjml)
    end
  end

  describe "get_content_slots/2 with html" do
    test "extracts slots anywhere in the document" do
      html = """
      <html><body>
        <keila-content name="top">A</keila-content>
        <div>
          <keila-content name="nested">B</keila-content>
        </div>
      </body></html>
      """

      assert [%Slot{name: "top"}, %Slot{name: "nested"}] =
               Templates.get_content_slots(html, mode: :html)
    end
  end

  describe "get_content_slots/2 with text" do
    test "extracts slot names with their default content" do
      text = ~s(Hello\n<keila-content name="main">Default</keila-content>\nGoodbye)

      assert [%Slot{name: "main", default_content: "Default"}] =
               Templates.get_content_slots(text, mode: :text)
    end

    test "returns empty list for nil input" do
      assert Templates.get_content_slots(nil, mode: :text) == []
    end
  end

  describe "merge_content_slots/3 with mjml" do
    test "fills provided slots and falls back to defaults for the rest" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="a">Default A</keila-content><keila-content name="b">Default B</keila-content></mj-body></mjml>)

      out = Templates.merge_content_slots(mjml, %{"a" => "AA"}, mode: :mjml)
      assert out == ~s(<mjml><mj-body>AADefault B</mj-body></mjml>)
    end

    test "nil mjml input returns nil" do
      assert Templates.merge_content_slots(nil, %{}, mode: :mjml) == nil
    end

    test "nil content map is treated as empty (defaults rendered)" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="hero">Default</keila-content></mj-body></mjml>)

      out = Templates.merge_content_slots(mjml, nil, mode: :mjml)
      assert out == ~s(<mjml><mj-body>Default</mj-body></mjml>)
    end

    test "preserves Liquid (literal `\"` etc.) in user-supplied slot content" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="main">d</keila-content></mj-body></mjml>)

      content = %{
        "main" => ~s(<mj-text>Hi {{ contact.first_name | default: "there" }}</mj-text>)
      }

      out = Templates.merge_content_slots(mjml, content, mode: :mjml)

      assert out ==
               ~s(<mjml><mj-body><mj-text>Hi {{ contact.first_name | default: "there" }}</mj-text></mj-body></mjml>)
    end

    test "leaves <mj-head> and its self-closing tags untouched while merging the body" do
      mjml =
        ~s(<mjml><mj-head><mj-attributes><mj-section background-color="#fff" /><mj-button color="#000" /></mj-attributes></mj-head><mj-body><keila-content name="main">Hi</keila-content></mj-body></mjml>)

      out = Templates.merge_content_slots(mjml, %{}, mode: :mjml)

      # The head is stashed and restored verbatim, so self-closing tags stay
      # self-closing and don't get mangled by the HTML parser.
      assert out =~
               ~s(<mj-head><mj-attributes><mj-section background-color="#fff" /><mj-button color="#000" /></mj-attributes></mj-head>)

      assert out =~ "<mj-body>Hi</mj-body>"
    end

    test "leaves a self-closing body element untouched, not swallowing its sibling" do
      mjml =
        ~s(<mjml><mj-body><mj-section><mj-column><mj-divider border-width="1px" /><mj-text>after</mj-text></mj-column></mj-section><keila-content name="main">x</keila-content></mj-body></mjml>)

      out = Templates.merge_content_slots(mjml, %{}, mode: :mjml)

      # The divider stays self-closing and <mj-text> stays its sibling.
      assert out =~ ~s(<mj-divider border-width="1px" /><mj-text>after</mj-text>)
      assert out =~ "<mj-body><mj-section>"
      refute out =~ "<keila-content"
    end

    test "preserves self-closing elements inside user-supplied slot content" do
      mjml =
        ~s(<mjml><mj-body><keila-content name="main">d</keila-content></mj-body></mjml>)

      content = %{"main" => ~s(<mj-image src="x.png" /><mj-text>hi</mj-text>)}
      out = Templates.merge_content_slots(mjml, content, mode: :mjml)

      assert out =~ ~s(<mj-image src="x.png" /><mj-text>hi</mj-text>)
    end

    test "preserves special characters inside Liquid tags, escapes them outside" do
      mjml = """
      <mjml><mj-body>
        <mj-text>
          &lt;outside&gt; &amp; text
          {{ x | default: "<inside> & quote" }}
          {% if a < b %}yes{% endif %}
        </mj-text>
      </mj-body></mjml>
      """

      out = Templates.merge_content_slots(mjml, %{}, mode: :mjml)

      assert out =~ ~s({{ x | default: "<inside> & quote" }})
      assert out =~ "{% if a < b %}"
      assert out =~ "&lt;outside&gt;"
      assert out =~ "&amp; text"
    end
  end

  describe "merge_content_slots/3 with html" do
    test "fills slots at any depth" do
      html =
        ~s(<div><keila-content name="top">A</keila-content><section><keila-content name="nested">B</keila-content></section></div>)

      out =
        Templates.merge_content_slots(html, %{"top" => "TOP", "nested" => "NESTED"}, mode: :html)

      assert out == ~s(<div>TOP<section>NESTED</section></div>)
    end
  end

  describe "merge_content_slots/3 with text" do
    test "replaces slot with supplied content" do
      text = ~s(Hi <keila-content name="x">default</keila-content>!)
      assert Templates.merge_content_slots(text, %{"x" => "world"}, mode: :text) == "Hi world!"
    end

    test "strips single line break adjacent to opening or closing tag" do
      text = """
      Before.

      <keila-content name="main">
      Body
      </keila-content>

      After.
      """

      out = Templates.merge_content_slots(text, %{"main" => "X"}, mode: :text)
      assert out == "Before.\n\nX\n\nAfter.\n"
    end
  end

  describe "merge_content_slots/3 without slots" do
    test "returns input unchanged for every mode" do
      mjml = ~s(<mjml><mj-body><mj-text>Hello</mj-text></mj-body></mjml>)
      assert Templates.merge_content_slots(mjml, %{"x" => "y"}, mode: :mjml) == mjml

      html = ~s(<div><p>Hello</p></div>)
      assert Templates.merge_content_slots(html, %{"x" => "y"}, mode: :html) == html

      text = "Just plain text, no slots."
      assert Templates.merge_content_slots(text, %{"x" => "y"}, mode: :text) == text
    end
  end
end
