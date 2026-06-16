defmodule Keila.Mailings.CampaignRenderer do
  @moduledoc """
  Module for rendering a `Keila.Mailings.Campaign` into a `Keila.Mailings.Renderer.Output`
  struct with `render/2` and `render_preview/2`. `to_input/3` maps a campaign into a
  `Keila.Mailings.Renderer.Input`. Tracking is implemented as a post-render step.
  """

  alias Keila.Mailings.Campaign
  alias Keila.Mailings.Message
  alias Keila.Mailings.Renderer
  alias Keila.Mailings.Renderer.{Input, Output}
  alias Keila.Contacts.Contact
  alias KeilaWeb.Router.Helpers, as: Routes
  require Logger

  @doc """
  Renders a campaign message into `Output` and applies open/click tracking if enabled.
  """
  @spec render(Campaign.t(), Message.t()) :: Output.t()
  def render(%Campaign{} = campaign, %Message{} = message) do
    unsubscribe_link = Keila.Mailings.get_unsubscribe_link(campaign.project_id, message.id)

    campaign
    |> to_input(message.contact, %{"unsubscribe_link" => unsubscribe_link})
    |> Renderer.render()
    |> maybe_put_tracking(campaign, message)
  end

  @default_preview_contact %Contact{
    id: "c_id",
    first_name: "Jane",
    last_name: "Doe",
    email: "jane.doe@example.com",
    data: %{}
  }

  @doc """
  Renders a campaign preview with a placeholder unsubscribe link and a sample
  contact (unless one is provided).
  """
  @spec render_preview(Campaign.t(), Contact.t()) :: Output.t()
  def render_preview(%Campaign{} = campaign, contact \\ @default_preview_contact) do
    campaign
    |> to_input(contact)
    |> Renderer.render_preview()
  end

  @doc "Maps a campaign and contact into an Input."
  @spec to_input(Campaign.t(), Contact.t() | nil, map()) :: Input.t()
  def to_input(%Campaign{} = campaign, contact, assigns \\ %{}) do
    assigns =
      assigns
      |> Map.put_new("campaign", Map.take(campaign, [:data, :subject, :preview_text]))
      |> maybe_put_public_link(campaign)

    %Input{
      type: campaign.settings.type,
      subject: campaign.subject,
      mjml_body: campaign.mjml_body,
      html_body: campaign.html_body,
      text_body: campaign.text_body,
      json_body: campaign.json_body,
      mjml_content: campaign.mjml_content,
      html_content: campaign.html_content,
      text_content: campaign.text_content,
      template: campaign.template,
      contact: contact,
      recipient_email: contact && contact.email,
      assigns: assigns
    }
  end

  defp maybe_put_public_link(assigns, %{public_link_enabled: true, id: id}) when not is_nil(id) do
    put_in(assigns, ["campaign", "public_link"], Keila.Mailings.get_public_campaign_link(id))
  end

  defp maybe_put_public_link(assigns, _campaign), do: assigns

  defp maybe_put_tracking(%Output{valid?: false} = output, _campaign, _message), do: output

  defp maybe_put_tracking(%Output{html_body: nil} = output, _campaign, _message),
    do: output

  defp maybe_put_tracking(output, %{settings: %{do_not_track: true}}, _message), do: output

  defp maybe_put_tracking(output, campaign, message) do
    html =
      output.html_body
      |> Floki.parse_document!()
      |> put_click_tracking(campaign.id, message.id)
      |> put_open_tracking(campaign.id, message.id)
      |> put_tracking_pixel(campaign.id, message.id)
      |> Keila.Templates.Html.to_document()

    %Output{output | html_body: html}
  rescue
    e ->
      Logger.warning(
        "CampaignRenderer: tracking failed for message #{message.id}, sending without tracking: #{Exception.message(e)}"
      )

      output
  end

  @tracking_click_selector "a[href^=\"https://\"], a[href^=\"http://\"]"
  defp put_click_tracking(html, campaign_id, message_id) do
    Floki.find_and_update(html, @tracking_click_selector, fn {tag, attributes} ->
      href = List.keyfind(attributes, "href", 0) |> elem(1)
      # if not Keila link
      if String.starts_with?(href, KeilaWeb.Endpoint.url()) do
        {tag, attributes}
      else
        link = Keila.Tracking.get_or_register_link(href, campaign_id)

        params = %{
          url: href,
          campaign_id: campaign_id,
          message_id: message_id,
          link_id: link.id
        }

        url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :click, params)

        {tag, List.keyreplace(attributes, "href", 0, {"href", url})}
      end
    end)
  end

  @tracking_open_selector "img[src^=\"https://\"], img[src^=\"http://\"]"
  defp put_open_tracking(html, campaign_id, message_id) do
    Floki.find_and_update(html, @tracking_open_selector, fn {tag, attributes} ->
      src = List.keyfind(attributes, "src", 0) |> elem(1)

      if String.starts_with?(src, KeilaWeb.Endpoint.url()) do
        {tag, attributes}
      else
        params = %{url: src, campaign_id: campaign_id, message_id: message_id}
        url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :open, params)

        {tag, List.keyreplace(attributes, "src", 0, {"src", url})}
      end
    end)
  end

  defp put_tracking_pixel(html, campaign_id, message_id) do
    pixel_url = Routes.static_url(KeilaWeb.Endpoint, "/images/pixel.gif")
    params = %{url: pixel_url, campaign_id: campaign_id, message_id: message_id}
    url = Keila.Tracking.get_tracking_url(KeilaWeb.Endpoint, :open, params)

    img = {"img", [{"src", url}], []}

    Floki.traverse_and_update(html, fn
      {"body", tags, children} -> {"body", tags, children ++ [img]}
      other -> other
    end)
  end
end
