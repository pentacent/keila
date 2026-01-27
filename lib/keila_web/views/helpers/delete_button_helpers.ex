defmodule KeilaWeb.DeleteButtonHelpers do
  @moduledoc """
  View helper module providing functions for creating forms and buttons to trigger
  a `DELETE` action for a given struct on a given route.
  """

  use Phoenix.Component
  use PhoenixHTMLHelpers

  attr :struct, :any, required: true
  attr :as, :atom, required: true
  attr :route, :string, required: true
  attr :return, :string
  slot :inner_block

  def delete_form(assigns) do
    assigns =
      assigns
      |> assign(:id, build_form_id(assigns.struct))

    ~H"""
    <.form :let={f} for={%{}} as={@as} id={@id} method="delete" action={@route} class="hidden">
      {hidden_input(f, :require_confirmation, value: "true")}
      <%= if assigns[:return] do %>
        {hidden_input(f, :return, value: assigns.return)}
      <% end %>
      {hidden_input(f, :id, value: @struct.id)}

      <%= if @inner_block != [] do %>
        {render_slot(@inner_block)}
      <% end %>
    </.form>
    """
  end

  attr :struct, :any
  attr :icon, :string
  attr :class, :string
  attr :"@click", :string
  slot :inner_block

  def delete_button(assigns) do
    assigns =
      assigns
      |> assign(:form_id, if(assigns[:struct], do: build_form_id(assigns.struct)))

    ~H"""
    <button type="submit" form={@form_id} class={@class} x-on:click={assigns[:"@click"]}>
      {maybe_render_icon(assigns[:icon])}
      <%= if @inner_block != [] do %>
        {render_slot(@inner_block)}
      <% end %>
    </button>
    """
  end

  defp build_form_id(struct) do
    "delete-form-#{struct.id}"
  end

  defp maybe_render_icon(:trash) do
    KeilaWeb.IconHelper.render_icon(:trash)
  end

  defp maybe_render_icon(_), do: []
end
