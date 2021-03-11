defmodule KeilaWeb.CampaignEditLive do
  use KeilaWeb, :live_view
  alias Keila.Mailings

  @impl true
  def mount(_params, session, socket) do
    project = session["current_project"]
    senders = session["senders"]
    campaign = session["campaign"]
    error_changeset = session["changeset"]

    changeset =
      case session["params"] do
        nil ->
          Ecto.Changeset.change(campaign)

        params ->
          changeset = Mailings.Campaign.update_changeset(campaign, params)

          case Ecto.Changeset.apply_action(changeset, :update) do
            {:error, changeset} -> changeset
            _ -> changeset
          end
      end

    recipient_count = Keila.Contacts.get_project_contacts_count(project.id)

    socket =
      socket
      |> assign(:current_project, project)
      |> assign(:campaign, campaign)
      |> assign(:senders, senders)
      |> assign(:changeset, changeset)
      |> assign(:recipient_count, recipient_count)
      |> assign(:error_changeset, error_changeset)
      |> put_default_assigns()

    {:ok, socket}
  end

  defp put_default_assigns(socket) do
    case Ecto.Changeset.apply_action(socket.assigns.changeset, :update) do
      {:ok, campaign} ->
        # TODO
        sender =
          Enum.find(socket.assigns.senders, &(&1.id == campaign.sender_id)) ||
            %Mailings.Sender{from_email: "foo@example.com"}

        campaign = %Mailings.Campaign{campaign | sender: sender}
        email = Mailings.Builder.build(campaign, %{})

        preview =
          case campaign.settings.type do
            :markdown -> email.html_body
            :text -> KeilaWeb.CampaignView.plain_text_preview(email.text_body)
          end

        assign(socket, :preview, preview)

      _ ->
        assign(socket, :preview, "")
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(KeilaWeb.CampaignView, "edit_live.html", assigns)
  end

  @impl true
  def handle_event("form_updated", params, socket) do
    changeset =
      Keila.Mailings.Campaign.preview_changeset(socket.assigns.campaign, params["campaign"])

    socket =
      socket
      |> assign(:changeset, changeset)
      |> put_default_assigns()

    {:noreply, socket}
  end
end
