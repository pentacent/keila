defmodule Keila.Mailings.Renderer.Input do
  @moduledoc """
  Input struct for `Keila.Mailings.Renderer.render/1`.
  """

  alias Keila.Templates.Template
  alias Keila.Contacts.Contact

  @type body_type :: :text | :markdown | :block | :mjml | :html

  @type t :: %__MODULE__{
          type: body_type() | nil,
          subject: String.t() | nil,
          mjml_body: String.t() | nil,
          html_body: String.t() | nil,
          text_body: String.t() | nil,
          json_body: map() | nil,
          mjml_content: map() | nil,
          html_content: map() | nil,
          text_content: map() | nil,
          template: Template.t() | nil,
          contact: Contact.t() | nil,
          recipient_email: String.t() | nil,
          recipient_name: String.t() | nil,
          assigns: map()
        }

  defstruct type: nil,
            subject: nil,
            mjml_body: nil,
            html_body: nil,
            text_body: nil,
            json_body: nil,
            mjml_content: nil,
            html_content: nil,
            text_content: nil,
            template: nil,
            contact: nil,
            recipient_email: nil,
            recipient_name: nil,
            assigns: %{}
end
