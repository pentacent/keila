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

  @doc """
  Renders a scaled-down preview of the page at `src`.
  """
  attr :href, :string, required: true
  attr :src, :string, required: true
  attr :title, :string, required: true

  def thumbnail_iframe(assigns) do
    ~H"""
    <a
      href={@href}
      class="block relative h-56 mb-4 rounded-md overflow-hidden bg-white shadow-lg ring-1 ring-white/10 transition hover:ring-2 hover:ring-emerald-500 after:absolute after:inset-x-0 after:bottom-0 after:h-12 after:bg-gradient-to-b after:from-transparent after:to-gray-800/60"
      aria-label={@title}
      tabindex="-1"
    >
      <iframe
        src={@src}
        loading="lazy"
        sandbox=""
        scrolling="no"
        tabindex="-1"
        title={@title}
        class="absolute top-0 left-0 w-[calc(100%/0.6)] h-[calc(100%/0.6)] scale-[0.6] origin-top-left border-0 pointer-events-none"
      >
      </iframe>
    </a>
    """
  end
end
