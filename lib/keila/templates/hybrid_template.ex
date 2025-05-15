defmodule Keila.Templates.HybridTemplate do
  @doc """
  Convenience module providing defaults for html and styles, as well as a style
  template configuration.
  """

  alias Keila.Templates.Css
  import KeilaWeb.Gettext

  @html_body File.read!("priv/email_templates/hybrid/hybrid.html.liquid") |> Solid.parse!()
  @styles File.read!("priv/email_templates/hybrid/default.css") |> Css.parse!()

  get_styles = fn selector, properties ->
    Enum.map(properties, fn property ->
      value = Css.get_value(@styles, selector, property)
      %{selector: selector, property: property, default: value}
    end)
  end

  @style_template [
    {gettext("Layout"),
     get_styles.(".email-bg", [
       "background-color"
     ]) ++ get_styles.("body", ["font-family"])},
    {gettext("Content"),
     get_styles.("#content", [
       "color",
       "background-color",
       "font-family"
     ])},
    {gettext("Heading 1"),
     get_styles.("h1", [
       "color",
       "font-family",
       "font-style",
       "font-weight",
       "text-decoration"
     ])},
    {gettext("Heading 2"),
     get_styles.("h2", [
       "color",
       "font-family",
       "font-style",
       "font-weight",
       "text-decoration"
     ])},
    {gettext("Heading 3"),
     get_styles.("h3", [
       "color",
       "font-family",
       "font-style",
       "font-weight",
       "text-decoration"
     ])},
    {gettext("Links"),
     get_styles.("a", [
       "color",
       "text-decoration"
     ])},
    {gettext("Buttons"),
     get_styles.(".block--button .button-a", [
       "color"
     ]) ++
       get_styles.(".block--button .button-td", [
         "background-color",
         "font-family",
         "font-style",
         "font-weight",
         "text-decoration"
       ])},
    {gettext("Quotes"),
     get_styles.(".block--quote blockquote, .block--quote figcaption", ["border-color"])},
    {gettext("Quote Text"), get_styles.(".block--quote blockquote", ["font-family", "color"])},
    {gettext("Quote Attribution"),
     get_styles.(".block--quote figcaption", ["font-family", "color"])},
    {gettext("Spacer"),
     get_styles.("hr", [
       "border-color",
       "opacity",
       "border-style",
       "margin"
     ])},
    {gettext("Footer"),
     get_styles.("#footer td", [
       "color",
       "text-align",
       "font-family",
       "font-style",
       "font-weight",
       "text-decoration"
     ])},
    {gettext("Footer links"),
     get_styles.("#footer td a", [
       "color",
       "text-decoration"
     ])}
  ]

  @signature """
  [Unsubscribe]({{ unsubscribe_link }})

  Powered by [Keila - OpenSource Newsletters](https://www.keila.io/)
  """

  @text_signature """
  Unsubscribe:
  {{ unsubscribe_link }}

  This newsletter is powered by Keila: https://www.keila.io
  """

  @spec styles() :: Keila.Templates.Css.t()
  def styles() do
    @styles
  end

  def embedded_styles() do
    [".email-bg"]
  end

  @spec html_template() :: %Solid.Template{}
  def html_template() do
    @html_body
  end

  def file_system() do
    path = Path.join(:code.priv_dir(:keila), "email_templates/hybrid") |> Path.absname()
    {Solid.LocalFileSystem, Solid.LocalFileSystem.new(path <> "/")}
  end

  @spec style_template() :: Keila.Templates.StyleTemplate.t()
  def style_template() do
    @style_template
  end

  @spec signature() :: String.t()
  def signature() do
    @signature
  end

  def text_signature() do
    @text_signature
  end
end
