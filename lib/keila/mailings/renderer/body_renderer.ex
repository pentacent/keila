defmodule Keila.Mailings.Renderer.BodyRenderer do
  @moduledoc """
  Behaviour for type-specific body renderers.

  `BodyRenderer` modules should only populate `html_body` and `text_body`
  as well as prepend any errors to `errors`.
  """

  alias Keila.Mailings.Renderer.{Input, Output}

  @callback render(Output.t(), Input.t(), map()) :: Output.t()
end
