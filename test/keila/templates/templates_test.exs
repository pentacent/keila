defmodule Keila.TemplatesTest do
  use ExUnit.Case, async: true
  alias Keila.Templates
  alias Keila.Templates.{Html, Css}

  doctest Keila.Templates.Html
  doctest Keila.Templates.Css

  @input_html """
  <div style="margin: 10px" class="foo">
    <a href="#">Link</a>
    <a href="#">Another Link</a>
  </div>
  """

  @input_css """
  .foo {
    background-color: #f0f;
  }
  div {
    padding: 10px;
  }
  a {
    color: blue;
  }
  """

  @expected_html """
                 <div style="margin: 10px;background-color:#f0f;padding:10px" class="foo">
                   <a href="#" style="color:blue">Link</a>
                   <a href="#" style="color:blue">Another Link</a>
                 </div>
                 """
                 |> String.replace(~r{\n\s*}, "")

  @tag :templates
  test "inline css" do
    html = Html.parse_fragment!(@input_html)
    css = Css.parse!(@input_css)
    assert @expected_html == Html.apply_inline_styles(html, css) |> Html.to_fragment()
  end
end
