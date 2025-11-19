defmodule KeilaWeb.SenderEditLive do
  use KeilaWeb, :live_view
  alias Keila.Mailings
  alias Keila.Mailings.Sender
  alias Keila.Mailings.Sender.Config
  alias Keila.Mailings.SenderAdapters
  import Ecto.Changeset

  @impl true
  def mount(_params, session, socket) do
    Gettext.put_locale(session["locale"])
    sender = Keila.Mailings.get_sender(session["sender"].id)

    if sender && connected?(socket) do
      Phoenix.PubSub.subscribe(Keila.PubSub, "sender:#{sender.id}")
    end

    {:ok,
     socket
     |> maybe_put_sender(sender)
     |> assign(:current_project, session["current_project"])
     |> assign(:shared_senders, Mailings.get_shared_senders())
     |> assign(:current_user, session["current_user"])}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.SenderView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("save", %{"sender" => sender_params}, socket) do
    case create_or_update_sender(socket, sender_params) do
      {:ok, _sender} ->
        {:noreply,
         socket
         |> redirect(to: Routes.sender_path(socket, :index, socket.assigns.current_project.id))}

      {:action_required, sender} ->
        {:noreply, maybe_put_sender(socket, sender)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)}
    end
  end

  def handle_event("send_verification_email", _, socket) do
    Keila.Mailings.send_sender_verification_email(socket.assigns.sender.id)

    {:noreply, socket}
  end

  defp create_or_update_sender(socket, params) do
    if socket.assigns.sender do
      Mailings.update_sender(socket.assigns.sender.id, params)
    else
      Mailings.create_sender(socket.assigns.current_project.id, params)
      |> tap(fn
        {:action_required, sender} ->
          Phoenix.PubSub.subscribe(Keila.PubSub, "sender:#{sender.id}")

        _ ->
          :ok
      end)
    end
  end

  @impl true
  def handle_info({:sender_updated, sender}, socket) do
    {:noreply, maybe_put_sender(socket, sender)}
  end

  def sender_status_component(%{config: %{type: "send_with_keila"}}),
    do: KeilaCloudWeb.Components.SharedSendWithKeilaStatus

  def sender_status_component(_), do: nil

  defp maybe_put_sender(socket, %Sender{} = sender) do
    adapter = SenderAdapters.get_adapter(sender.config.type)

    socket
    |> assign(:sender, sender)
    |> assign(:changeset, change(sender))
    |> assign(:configurable?, adapter.configurable?())
    |> assign(:adapter_requires_verification?, adapter.requires_verification?())
    |> assign(:sender_status_component, sender_status_component(sender))
  end

  defp maybe_put_sender(socket, nil) do
    socket
    |> assign(:sender, nil)
    |> assign(:changeset, change(%Sender{config: change(%Config{type: "smtp"})}))
    |> assign(:configurable?, true)
    |> assign(:adapter_requires_verification?, false)
    |> assign(:sender_status_component, sender_status_component(nil))
  end
end
