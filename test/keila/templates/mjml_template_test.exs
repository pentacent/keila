defmodule Keila.Templates.MjmlTemplateTest do
  use ExUnit.Case, async: true
  alias Keila.Templates.MjmlTemplate
  alias Keila.Templates.MjmlTemplate.Slot

  describe "remove_code_blocks/1" do
    test "strips opening, closing, and self-closing keila-code tags" do
      input = """
      <keila-code>{% assign x = 1 %}</keila-code>
      <mj-section><keila-code/></mj-section>
      <keila-code  >{% if x %}</keila-code  >
      <p>hi</p>
      <keila-code>{% endif %}</keila-code>
      """

      out = MjmlTemplate.remove_code_blocks(input)
      refute out =~ "keila-code"
      assert out =~ "{% assign x = 1 %}"
      assert out =~ "{% if x %}"
      assert out =~ "{% endif %}"
      assert out =~ "<p>hi</p>"
    end

    test "nil input returns nil" do
      assert MjmlTemplate.remove_code_blocks(nil) == nil
    end
  end

  describe "get_content_slots/1" do
    test "returns empty list when no slots present" do
      mjml = "<mjml><mj-body><mj-text>Hello</mj-text></mj-body></mjml>"
      assert MjmlTemplate.get_content_slots(mjml) == []
    end

    test "extracts slots with or without default content" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Hero default</keila-content>
        <keila-content name="main"></keila-content>
        <keila-content name="footer">Footer default</keila-content>
      </mj-body></mjml>
      """

      assert [
               %Slot{name: "hero", default_content: "Hero default" <> _},
               %Slot{name: "main", default_content: ""},
               %Slot{name: "footer", default_content: "Footer default" <> _}
             ] = MjmlTemplate.get_content_slots(mjml)
    end

    test "only direct children of mj-body are extracted as slots" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Direct child</keila-content>
        <mj-section><mj-column>
          <keila-content name="nested">should be ignored</keila-content>
        </mj-column></mj-section>
      </mj-body></mjml>
      """

      assert [%Slot{name: "hero"}] = MjmlTemplate.get_content_slots(mjml)
    end

    test "returns empty list for nil input" do
      assert MjmlTemplate.get_content_slots(nil) == []
    end

    test "skips slots without a name attribute" do
      mjml = """
      <mjml><mj-body>
        <keila-content>no name</keila-content>
        <keila-content name="">empty name</keila-content>
        <keila-content name="ok">y</keila-content>
      </mj-body></mjml>
      """

      assert [%Slot{name: "ok"}] = MjmlTemplate.get_content_slots(mjml)
    end
  end

  describe "merge_content_slots/2" do
    test "fills slots with the parsed replacement value" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="a">Default A</keila-content>
        <keila-content name="b">Default B</keila-content>
      </mj-body></mjml>
      """

      out = MjmlTemplate.merge_content_slots(mjml, %{"a" => "AA", "b" => "BB"})
      assert out =~ "AA"
      assert out =~ "BB"
      refute out =~ "Default A"
      refute out =~ "Default B"
      refute out =~ "keila-content"
    end

    test "falls back to default content when slot key is missing" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Default hero</keila-content>
      </mj-body></mjml>
      """

      out = MjmlTemplate.merge_content_slots(mjml, %{})
      refute out =~ "keila-content"
      assert out =~ "Default hero"
    end

    test "atom keys in the values map are accepted" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Default</keila-content>
      </mj-body></mjml>
      """

      out = MjmlTemplate.merge_content_slots(mjml, %{hero: "Custom"})
      assert out =~ "Custom"
    end

    test "nil mjml input returns nil" do
      assert MjmlTemplate.merge_content_slots(nil, %{"hero" => "x"}) == nil
    end

    test "nil content map is accepted (treated as empty)" do
      mjml = """
      <mjml><mj-body>
        <keila-content name="hero">Default</keila-content>
      </mj-body></mjml>
      """

      out = MjmlTemplate.merge_content_slots(mjml, nil)
      assert out =~ "Default"
      refute out =~ "keila-content"
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

      out = MjmlTemplate.merge_content_slots(mjml, %{})

      assert out =~ ~s({{ x | default: "<inside> & quote" }})
      assert out =~ "{% if a < b %}"

      assert out =~ "&lt;outside&gt;"
      assert out =~ "&amp; text"
    end
  end
end
