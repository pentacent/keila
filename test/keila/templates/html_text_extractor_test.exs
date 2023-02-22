defmodule Keila.Templates.HtmlTextExtractorTest do
  use Keila.DataCase, async: true

  @input """
  <!doctype html>
  <html>
  <body>
  <h1>Hello, world!</h1>
  <ul>
    <li>List Item 1</li>
    <li>
      List Item 2
      <ol>
        <li>Ordered List Item</li>
        <li>Ordered List Item</li>
      </ol>
    </li>
  </ul>
  <hr>
  <p>
    Here is a text with a



    <a href="https://example.com" title="Title">Link</a>
    and then some more text.
  </p>
  <blockquote>
    This is a blockquote.
  </blockquote>
  </body>
  </html>
  """

  @expected_output """
  # Hello, world!

  - List Item 1
  - List Item 2
    1. Ordered List Item
    2. Ordered List Item

  ---

  Here is a text with a [Link](https://example.com "Title") and then some more text.

  > This is a blockquote.
  """

  @tag :templates
  test "Extract text from HTML document" do
    html = Floki.parse_document!(@input)
    assert Keila.Templates.HtmlTextExtractor.extract_text(html) == @expected_output
  end
end
