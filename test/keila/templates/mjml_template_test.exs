defmodule Keila.Templates.MjmlTemplateTest do
  use ExUnit.Case, async: true
  alias Keila.Templates.MjmlTemplate

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
end
