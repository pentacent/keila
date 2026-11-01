defprotocol Keila.Mailings.Renderable do
  @moduledoc """
  Email content that can be turned into a `Keila.Mailings.Renderer.Input`.
  """

  @spec to_input(t(), Keila.Mailings.Email.recipient(), map()) ::
          Keila.Mailings.Renderer.Input.t()
  def to_input(renderable, recipient, assigns)
end
