defmodule KeilaWeb.DeleteButtonHelpers do
  @moduledoc """
  View helper module providing functions for creating forms and buttons to trigger
  a `DELETE` action for a given struct on a given route.
  """

  use Phoenix.HTML

  @spec delete_form_tag(struct(), String.t(), Keyword.t()) :: Phoenix.HTML.safe()
  def delete_form_tag(struct, route, opts) do
    as = Keyword.fetch!(opts, :as)

    form_for(
      as,
      route,
      [as: as, id: build_form_id(struct), method: "delete", class: "hidden"],
      fn f ->
        [
          hidden_input(f, :require_confirmation, value: "true"),
          hidden_input(f, :id, value: struct.id)
        ]
      end
    )
  end

  @spec delete_button_tag(struct(), Keyword.t(), term()) :: Phoenix.HTML.safe()
  def delete_button_tag(struct, opts \\ [], content)

  def delete_button_tag(struct, opts, do: content), do: delete_button_tag(struct, opts, content)

  def delete_button_tag(struct, opts, content) do
    icon = maybe_render_icon(opts[:icon])

    opts =
      opts
      |> Keyword.put_new(:class, "button")
      |> Keyword.put(:form, build_form_id(struct))
      |> Keyword.delete(:icon)

    content_tag(
      :button,
      [icon, content],
      opts
    )
  end

  defp build_form_id(struct) do
    "delete-form-#{struct.id}"
  end

  defp maybe_render_icon(:trash) do
    ~e{
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
      </svg>
    }
  end

  defp maybe_render_icon(_), do: []
end
