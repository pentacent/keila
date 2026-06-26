defmodule Keila.Templates.ContentSlotsTest do
  use ExUnit.Case, async: true
  alias Keila.Templates
  alias Keila.Templates.Slot

  @mjml """
  <mjml>
  <mj-head>
    <!-- slots not in mj-body are ignored -->
    <keila-content name="in-mj-head" />
  </mj-head>
  <mj-body>
    <!-- Comments are ignored even if they contain <keila-content name="comment" />
    or unclosed tags: <div> -->

    {{ Liquid tags are ignored even if they contain slot markup ot unclosed tags: <keila-content name="in-liquid" /> <div> }}

    <!-- self-closing slot with no default content -->
    <keila-content name="empty-slot" />

    <!-- single quote and no quote for the name attr is allowed -->
    <keila-content name='single-quoted'>Single Quoted</keila-content>
    <keila-content name=unquoted>Unquoted</keila-content>

    <!-- slots cannot be nested inside elements other than mj-body -->
    <mj-section>
      <keila-content name="nested-in-section" />
    </mj-section>


    <!-- default content is extracted -->
    <keila-content name="main">
      <mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>

      <!-- nested slots are not extracted -->
      <keila-content name="nested-in-slot">ignored</keila-content>

      <!-- self-closing mjml elements and void elements don't break things -->
      <mj-section>
        <mj-divider />
        <br><img>
      </mj-section>
    </keila-content>
  </mj-body></mjml>
  """

  describe "mjml slots" do
    test "are extracted if they're direct children of mj-body" do
      assert [
               %Slot{name: "empty-slot", default_content: ""},
               %Slot{name: "single-quoted", default_content: "Single Quoted"},
               %Slot{name: "unquoted", default_content: "Unquoted"},
               %Slot{name: "main", default_content: main}
             ] = Templates.get_content_slots(@mjml, mode: :mjml)

      # The default content is dedented and surrounding empty lines are trimmed.
      assert main ==
               String.trim("""
               <mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>

               <!-- nested slots are not extracted -->
               <keila-content name="nested-in-slot">ignored</keila-content>

               <!-- self-closing mjml elements and void elements don't break things -->
               <mj-section>
                 <mj-divider />
                 <br><img>
               </mj-section>
               """)
    end

    test "are filled with provided content or default content" do
      content = %{
        "empty-slot" => ~s(<mj-button>Click</mj-button>),
        "single-quoted" => ~s(<mj-text>Hi {{ name }}</mj-text>),
        "main" => "MAIN"
      }

      assert Templates.merge_content_slots(@mjml, content, mode: :mjml) ==
               """
               <mjml>
               <mj-head>
                 <!-- slots not in mj-body are ignored -->
                 <keila-content name="in-mj-head" />
               </mj-head>
               <mj-body>
                 <!-- Comments are ignored even if they contain <keila-content name="comment" />
                 or unclosed tags: <div> -->

                 {{ Liquid tags are ignored even if they contain slot markup ot unclosed tags: <keila-content name="in-liquid" /> <div> }}

                 <!-- self-closing slot with no default content -->
                 <mj-button>Click</mj-button>

                 <!-- single quote and no quote for the name attr is allowed -->
                 <mj-text>Hi {{ name }}</mj-text>
                 Unquoted

                 <!-- slots cannot be nested inside elements other than mj-body -->
                 <mj-section>
                   <keila-content name="nested-in-section" />
                 </mj-section>


                 <!-- default content is extracted -->
                 MAIN
               </mj-body></mjml>
               """
    end
  end

  @html """
  <html>
    <body>
      <!-- unlike mjml, html slots are not restricted to a single level -->
      <keila-content name="top">Top</keila-content>

      <div>
        <section>
          <keila-content name="deeply-nested">Deep</keila-content>
        </section>
      </div>

      <!-- single, double, and unquoted names are accepted -->
      <keila-content name='single-quoted'>Single</keila-content>
      <keila-content name=unquoted>Unquoted</keila-content>

      <!-- default content is extracted and dedented -->
      <keila-content name="main">
        <div>
          <p>Hello</p>
        </div>
      </keila-content>
    </body>
  </html>
  """

  describe "html slots" do
    test "are extracted" do
      assert [
               %Slot{name: "top", default_content: "Top"},
               %Slot{name: "deeply-nested", default_content: "Deep"},
               %Slot{name: "single-quoted", default_content: "Single"},
               %Slot{name: "unquoted", default_content: "Unquoted"},
               %Slot{name: "main", default_content: main}
             ] = Templates.get_content_slots(@html, mode: :html)

      assert main == "<div>\n  <p>Hello</p>\n</div>"
    end

    test "are filled with provided content or default content" do
      content = %{
        "top" => "<h1>Hi</h1>",
        "deeply-nested" => "<p>D</p>",
        "single-quoted" => "<em>S</em>",
        "main" => "<p>Main</p>"
      }

      assert Templates.merge_content_slots(@html, content, mode: :html) ==
               """
               <html>
                 <body>
                   <!-- unlike mjml, html slots are not restricted to a single level -->
                   <h1>Hi</h1>

                   <div>
                     <section>
                       <p>D</p>
                     </section>
                   </div>

                   <!-- single, double, and unquoted names are accepted -->
                   <em>S</em>
                   Unquoted

                   <!-- default content is extracted and dedented -->
                   <p>Main</p>
                 </body>
               </html>
               """
    end
  end

  @text """
  Welcome to our newsletter!

  <keila-content name="intro">Intro paragraph.</keila-content>

  Here is an <keila-content name='inline'>inline</keila-content> slot mid-sentence.

  <keila-content name=unquoted>Unquoted</keila-content>

  <keila-content name="block">
    Line one
    Line two
  </keila-content>

  Thanks for reading.
  """

  describe "text slots" do
    test "are extracted" do
      assert [
               %Slot{name: "intro", default_content: "Intro paragraph."},
               %Slot{name: "inline", default_content: "inline"},
               %Slot{name: "unquoted", default_content: "Unquoted"},
               %Slot{name: "block", default_content: block}
             ] = Templates.get_content_slots(@text, mode: :text)

      assert block == "Line one\nLine two"
    end

    test "are filled with provided content or default content" do
      content = %{"intro" => "Welcome", "inline" => "INLINE", "block" => "BLOCK"}

      assert Templates.merge_content_slots(@text, content, mode: :text) ==
               """
               Welcome to our newsletter!

               Welcome

               Here is an INLINE slot mid-sentence.

               Unquoted

               BLOCK

               Thanks for reading.
               """
    end
  end

  describe "nil and slot-less inputs" do
    test "get_content_slots returns [] and merge_content_slots returns nil for nil input" do
      for mode <- [:mjml, :html, :text] do
        assert Templates.get_content_slots(nil, mode: mode) == []
        assert Templates.merge_content_slots(nil, %{}, mode: mode) == nil
      end
    end

    test "merge_content_slots returns the input unchanged when there are no slots" do
      mjml = ~s(<mjml><mj-body><mj-text>Hello</mj-text></mj-body></mjml>)
      assert Templates.merge_content_slots(mjml, %{"x" => "y"}, mode: :mjml) == mjml

      html = ~s(<div><p>Hello</p></div>)
      assert Templates.merge_content_slots(html, %{"x" => "y"}, mode: :html) == html

      text = "Just plain text, no slots."
      assert Templates.merge_content_slots(text, %{"x" => "y"}, mode: :text) == text
    end
  end
end
