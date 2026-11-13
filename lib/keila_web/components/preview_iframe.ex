defmodule KeilaWeb.PreviewIframe do
  @moduledoc """
  Components for securely showing user-created email HTML in sandboxed iframes.
  """
  use Phoenix.Component
  use KeilaWeb.Gettext

  @doc """
  Renders an empty iframe that can be filled by the `HtmlPreview` hook.

  `allow-same-origin` is required for the hook to write into the iframe and
  restore its scroll position. `allow-popups` and `allow-popups-to-escape-sandbox`
  let links in the email open unsandboxed in a new tab.
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :rest, :global, include: ~w(x-bind:class x-bind:style)

  def preview_iframe(assigns) do
    ~H"""
    <iframe
      id={@id}
      src="about:blank"
      sandbox="allow-same-origin allow-popups allow-popups-to-escape-sandbox"
      title={@title || gettext("Email preview")}
      {@rest}
    >
    </iframe>
    """
  end
end
