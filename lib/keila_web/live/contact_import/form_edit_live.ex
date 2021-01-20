defmodule KeilaWeb.FormEditLive do
  use KeilaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:form, session["form"])
      |> assign(:changeset, Ecto.Changeset.change(session["form"]))
      |> assign(:current_project, session["current_project"])
      |> put_default_assigns()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.FormView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", params, socket) do
    changeset = Keila.Contacts.Form.update_changeset(socket.assigns.form, params["form"])

    socket =
      socket
      |> assign(:changeset, changeset)
      |> put_default_assigns()

    {:noreply, socket}
  end

  defp put_default_assigns(socket) do
    form_preview =
      case Ecto.Changeset.apply_action(socket.assigns.changeset, :update) do
        {:ok, form} -> form
        _ -> nil
      end

    embed =
      KeilaWeb.FormView.render("form.html", %{
        form: form_preview,
        mode: :embed,
        changeset: Ecto.Changeset.change(%Keila.Contacts.Contact{})
      })

    socket
    |> assign(:form_preview, form_preview)
    |> assign(:embed, embed)
  end
end
