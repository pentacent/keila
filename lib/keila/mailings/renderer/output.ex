defmodule Keila.Mailings.Renderer.Output do
  @moduledoc """
  The output struct for `Keila.Mailings.Renderer.render/1`.
  Contains rendered bodies and subject.
  `valid?` indicates if an error occurred during rendering; `errors`
  may contain a list of error strings.
  """

  @type t :: %__MODULE__{
          subject: String.t() | nil,
          html_body: String.t() | nil,
          text_body: String.t() | nil,
          valid?: boolean(),
          errors: [String.t()]
        }

  defstruct subject: nil, html_body: nil, text_body: nil, valid?: true, errors: []
end
