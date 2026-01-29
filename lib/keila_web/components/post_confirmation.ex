defmodule KeilaWeb.PostConfirmation do
  @moduledoc """
  Component for confirming actions via POST after a timeout.
  """
  use Phoenix.Component
  use KeilaWeb.Gettext
  import KeilaWeb.IconHelper

  @doc """
  Renders a confirmation form that auto-submits after a timeout.

  This component is designed to also work when JavaScript is disabled.
  In that case, instead of `message`, `action_message` is displayed
  and a button labelled with `action_cta` is rendered.
  """
  attr :href, :any, default: false
  attr :message, :string, required: true
  attr :action_message, :string, required: true
  attr :action_cta, :string, required: true
  attr :timeout, :integer, default: 3000

  def post_confirmation(assigns) do
    assigns =
      assigns
      |> assign(:csrf_token, Phoenix.Controller.get_csrf_token())
      |> assign(:form_id, "post-confirmation-#{System.unique_integer([:positive])}")

    ~H"""
    <form id={@form_id} action={@href} method="post" class="post-confirmation" data-timeout={@timeout}>
      <input type="hidden" name="_csrf_token" value={@csrf_token} />

      <div
        class="flex flex-col gap-4"
        data-jsonly-display="flex"
        style="display: none;"
      >
        <div class="flex flex-row items-center">
          <div class="w-12 h-12 flex animate-spin mr-4" style="animation-duration: 3000ms;">
            {render_icon(:spinner)}
          </div>
          <p class="text-lg">{@message}</p>
        </div>
      </div>

      <noscript>
        <div class="flex flex-col gap-4">
          <p class="text-lg">{@action_message}</p>
          <div class="flex justify-start">
            <button type="submit" class="button button--cta button--large">
              {@action_cta}
            </button>
          </div>
        </div>
      </noscript>

      <script>
        (function() {
          const form = document.getElementById("<%= @form_id %>")
          const timeout = parseInt(form.dataset.timeout, 10)
          setTimeout(form.submit, timeout)

          form.querySelectorAll('[data-jsonly-display]').forEach(function(element) {
            element.style.display = element.dataset.jsonlyDisplay
          })
        })()
      </script>
    </form>
    """
  end
end
