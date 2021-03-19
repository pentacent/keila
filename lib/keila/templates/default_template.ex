defmodule Keila.Templates.DefaultTemplate do
  @doc """
  Convenience module providing defaults for html and styles, as well as a style
  template configuration.
  """

  alias Keila.Templates.Css
  import KeilaWeb.Gettext

  @html_body File.read!("priv/email_templates/default.html.liquid") |> Solid.parse!()
  @styles File.read!("priv/email_templates/default.css") |> Css.parse!()
  @style_template [
    {gettext("Layout"),
     [
       %{
         selector: "body, #center-wrapper, #table-wrapper",
         property: "background-color",
         default: "#f3f4f6"
       },
       %{
         selector: "body, #center-wrapper, #table-wrapper",
         property: "font-family",
         default: "Verdana, sans-serif"
       }
     ]},
    {gettext("Content"),
     [
       %{
         selector: "#content",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "#content",
         property: "background-color",
         default: "#ffffff"
       },
       %{
         selector: "#content",
         property: "color",
         default: "#1f2937"
       }
     ]},
    {gettext("Heading 1"),
     [
       %{
         selector: "h1",
         property: "color",
         default: "#4b5563"
       },
       %{
         selector: "h1",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "h1",
         property: "font-style",
         default: "normal"
       },
       %{
         selector: "h1",
         property: "font-weight",
         default: "bold"
       },
       %{
         selector: "h1",
         property: "text-decoration",
         default: "none"
       }
     ]},
    {gettext("Heading 2"),
     [
       %{
         selector: "h2",
         property: "color",
         default: "#4b5563"
       },
       %{
         selector: "h2",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "h2",
         property: "font-style",
         default: "normal"
       },
       %{
         selector: "h2",
         property: "font-weight",
         default: "bold"
       },
       %{
         selector: "h2",
         property: "text-decoration",
         default: "none"
       }
     ]},
    {gettext("Heading 3"),
     [
       %{
         selector: "h3",
         property: "color",
         default: "#4b5563"
       },
       %{
         selector: "h3",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "h3",
         property: "font-style",
         default: "normal"
       },
       %{
         selector: "h3",
         property: "font-weight",
         default: "bold"
       },
       %{
         selector: "h3",
         property: "text-decoration",
         default: "none"
       }
     ]},
    {gettext("Links"),
     [
       %{
         selector: "a",
         property: "color",
         default: "#1d4ed8"
       },
       %{
         selector: "h4 a",
         property: "text-decoration",
         default: "underline"
       }
     ]},
    {gettext("Button"),
     [
       %{
         selector: "h4 a",
         property: "background-color",
         default: "#1d4ed8"
       },
       %{
         selector: "h4 a",
         property: "color",
         default: "#ffffff"
       },
       %{
         selector: "h4 a",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "h4 a",
         property: "font-style",
         default: "normal"
       },
       %{
         selector: "h4 a",
         property: "font-weight",
         default: "bold"
       },
       %{
         selector: "h4 a",
         property: "text-decoration",
         default: "none"
       }
     ]},
    {gettext("Signature"),
     [
       %{
         selector: "#signature td",
         property: "color",
         default: "#4b5563"
       },
       %{
         selector: "#signature td",
         property: "font-family",
         default: "inherit"
       },
       %{
         selector: "#signature td",
         property: "font-style",
         default: "normal"
       },
       %{
         selector: "#signature td",
         property: "font-weight",
         default: "bold"
       },
       %{
         selector: "#signature td",
         property: "text-decoration",
         default: "none"
       }
     ]},
    {gettext("Signature links"),
     [
       %{
         selector: "#signature td a",
         property: "color",
         default: "#374151"
       },
       %{
         selector: "#signature td a",
         property: "text-decoration",
         default: "underline"
       }
     ]}
  ]

  @spec styles() :: Keila.Templates.Css.t()
  def styles() do
    @styles
  end

  @spec html_template() :: %Solid.Template{}
  def html_template() do
    @html_body
  end

  @spec style_template() :: Keila.Templates.StyleTemplate.t()
  def style_template() do
    @style_template
  end
end
